-- =============================================================================
-- V006__phase4_economy_social.sql
-- Phase 4: Economy, Social & World Events
-- Aetheria — Never edit after apply. Create V007 for any changes.
--
-- KEY NOTES:
--   1. World event HP is tracked in Redis per-hit, not Postgres
--      hp_remaining in world_events is only synced on zone move + event end
--   2. auction_listings current_bid is updated in Postgres on each bid
--      (low frequency enough to not need Redis)
--   3. notifications.expires_at — a cron job cleans up expired rows
-- =============================================================================

-- =============================================================================
-- 1. trades
-- Direct player-to-player Aether trades.
-- Both sides must confirm before the trade executes.
-- currency_sweetener = one side adding currency to balance an uneven trade.
-- Depends on: users, aether_instances
-- =============================================================================
CREATE TABLE trades (
    trade_id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),

    -- The two sides
    initiator_id            UUID        NOT NULL REFERENCES users(user_id),
    receiver_id             UUID        NOT NULL REFERENCES users(user_id),

    -- What each side is offering
    initiator_instance_id   UUID        NOT NULL REFERENCES aether_instances(instance_id),
    receiver_instance_id    UUID        REFERENCES aether_instances(instance_id), -- NULL = currency-only offer
    currency_sweetener      INTEGER     NOT NULL DEFAULT 0 CHECK (currency_sweetener >= 0),

    -- Fair-value scores computed server-side at trade proposal time
    trade_value_initiator   INTEGER     NOT NULL DEFAULT 0 CHECK (trade_value_initiator >= 0),
    trade_value_receiver    INTEGER     NOT NULL DEFAULT 0 CHECK (trade_value_receiver >= 0),

    status                  VARCHAR(20) NOT NULL DEFAULT 'PENDING'
                                CHECK (status IN (
                                    'PENDING',      -- waiting for receiver to respond
                                    'ACCEPTED',     -- receiver accepted, executing
                                    'COMPLETED',    -- trade executed successfully
                                    'REJECTED',     -- receiver rejected
                                    'CANCELLED',    -- initiator cancelled
                                    'EXPIRED'       -- timed out (24hr no response)
                                )),

    -- Flagged if trade_value difference is extreme (anti-RMT)
    is_flagged_unfair       BOOLEAN     NOT NULL DEFAULT FALSE,

    -- True if the trade triggered an evolution for either Aether
    triggered_evolution     BOOLEAN     NOT NULL DEFAULT FALSE,

    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at            TIMESTAMPTZ,

    CHECK (initiator_id != receiver_id) -- can't trade with yourself
);


-- =============================================================================
-- 2. auction_listings
-- Players list Aethers for public auction. Others bid.
-- buy_now_price = optional instant purchase price (NULL = auction only).
-- Depends on: users, aether_instances
-- =============================================================================
CREATE TABLE auction_listings (
    auction_id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_id           UUID        NOT NULL REFERENCES users(user_id),
    instance_id         UUID        NOT NULL UNIQUE REFERENCES aether_instances(instance_id),
                                    -- UNIQUE: one auction per Aether at a time

    starting_bid        INTEGER     NOT NULL DEFAULT 1 CHECK (starting_bid > 0),
    current_bid         INTEGER     NOT NULL DEFAULT 0 CHECK (current_bid >= 0),
    current_bidder_id   UUID        REFERENCES users(user_id), -- NULL = no bids yet
    buy_now_price       INTEGER     CHECK (buy_now_price IS NULL OR buy_now_price > starting_bid),

    starts_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    ends_at             TIMESTAMPTZ NOT NULL,

    status              VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
                            CHECK (status IN (
                                'ACTIVE',       -- bidding open
                                'SOLD',         -- buy_now used or auction won
                                'UNSOLD',       -- ended with no bids
                                'CANCELLED'     -- seller cancelled (only if no bids yet)
                            )),

    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    CHECK (ends_at > starts_at)
);


-- =============================================================================
-- 3. auction_bid_history
-- Full record of every bid placed on every auction.
-- Depends on: auction_listings, users
-- =============================================================================
CREATE TABLE auction_bid_history (
    bid_id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    auction_id      UUID        NOT NULL REFERENCES auction_listings(auction_id),
    bidder_id       UUID        NOT NULL REFERENCES users(user_id),
    amount          INTEGER     NOT NULL CHECK (amount > 0),
    placed_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- =============================================================================
-- 4. notifications
-- In-app notifications for each player.
-- type examples: 'TRADE_OFFER', 'AUCTION_OUTBID', 'AUCTION_WON',
--                'WORLD_EVENT_START', 'RIVAL_CHALLENGE', 'QUEST_COMPLETE'
-- payload is flexible JSONB — contents vary by type.
-- expires_at — notifications are auto-cleaned by a cron job after expiry.
-- Depends on: users
-- =============================================================================
CREATE TABLE notifications (
    notification_id UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID        NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    type            VARCHAR(30) NOT NULL
                        CHECK (type IN (
                            'TRADE_OFFER',
                            'TRADE_ACCEPTED',
                            'TRADE_REJECTED',
                            'TRADE_COMPLETED',
                            'AUCTION_OUTBID',
                            'AUCTION_WON',
                            'AUCTION_ENDED',
                            'WORLD_EVENT_START',
                            'WORLD_EVENT_CATCHABLE',
                            'RIVAL_CHALLENGE',
                            'QUEST_UNLOCKED',
                            'QUEST_COMPLETE',
                            'STREAK_MILESTONE',
                            'GUILD_INVITE',
                            'GUILD_MESSAGE',
                            'SYSTEM'
                        )),
    payload         JSONB       NOT NULL DEFAULT '{}',
                    -- e.g. { "trade_id": "...", "from": "username" }
                    --      { "auction_id": "...", "new_bid": 500 }
    is_read         BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at      TIMESTAMPTZ -- NULL = never expires
);


-- =============================================================================
-- 5. world_events
-- A God-tier Aether that appears globally and moves between zones every 30 min.
-- Shared HP pool — all players chip away at the same creature.
-- HP is tracked in Redis per-hit. hp_remaining here is synced only on:
--   a) zone move (every 30 min)
--   b) event end
-- Depends on: aether_species, zones
-- =============================================================================
CREATE TABLE world_events (
    event_id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type          VARCHAR(30) NOT NULL
                            CHECK (event_type IN (
                                'GOD_TIER_SPAWN',   -- main world event type
                                'LEGENDARY_SURGE',  -- legendary appears in multiple zones
                                'FACTION_WAR'       -- faction-based event
                            )),
    species_id          INTEGER     NOT NULL REFERENCES aether_species(id),
    current_zone_id     INTEGER     REFERENCES zones(id),

    -- Zone movement tracking
    last_moved_at       TIMESTAMPTZ,
    next_move_at        TIMESTAMPTZ,   -- computed: last_moved_at + 30 minutes

    -- HP — synced from Redis on zone move and event end
    hp_remaining        INTEGER     NOT NULL CHECK (hp_remaining >= 0),
    max_hp              INTEGER     NOT NULL CHECK (max_hp > 0),

    -- Catchable once HP drops below 20%
    is_catchable        BOOLEAN     NOT NULL DEFAULT FALSE,

    starts_at           TIMESTAMPTZ NOT NULL,
    ends_at             TIMESTAMPTZ NOT NULL,
    is_active           BOOLEAN     NOT NULL DEFAULT FALSE,

    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    CHECK (ends_at > starts_at),
    CHECK (hp_remaining <= max_hp)
);


-- =============================================================================
-- 6. world_event_participants
-- Records every player who joined a world event and their contribution.
-- One row per player per event.
-- caught_it = TRUE for the first (and only) player to catch the creature.
-- Depends on: world_events, users
-- =============================================================================
CREATE TABLE world_event_participants (
    participation_id    UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id            UUID        NOT NULL REFERENCES world_events(event_id),
    user_id             UUID        NOT NULL REFERENCES users(user_id),
    damage_contributed  INTEGER     NOT NULL DEFAULT 0 CHECK (damage_contributed >= 0),
    joined_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    caught_it           BOOLEAN     NOT NULL DEFAULT FALSE,
    UNIQUE (event_id, user_id)      -- one entry per player per event
);


-- =============================================================================
-- 7. guilds
-- Player-created groups. A guild can control a zone and earn bonuses.
-- controlled_zone_id = the zone this guild currently dominates (NULL = none).
-- Depends on: users, zones
-- =============================================================================
CREATE TABLE guilds (
    guild_id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    name                    VARCHAR(50) NOT NULL UNIQUE,
    leader_id               UUID        NOT NULL REFERENCES users(user_id),
    controlled_zone_id      INTEGER     REFERENCES zones(id),
    zone_controlled_since   TIMESTAMPTZ,
    guild_xp                INTEGER     NOT NULL DEFAULT 0 CHECK (guild_xp >= 0),
    emblem_config           JSONB,      -- { "icon": "...", "color": "...", "border": "..." }
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- =============================================================================
-- 8. guild_members
-- Junction: players who belong to a guild.
-- role: LEADER = guild creator, OFFICER = can invite/kick, MEMBER = standard
-- Depends on: guilds, users
-- =============================================================================
CREATE TABLE guild_members (
    membership_id   UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    guild_id        UUID        NOT NULL REFERENCES guilds(guild_id) ON DELETE CASCADE,
    user_id         UUID        NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    role            VARCHAR(10) NOT NULL DEFAULT 'MEMBER'
                        CHECK (role IN ('LEADER', 'OFFICER', 'MEMBER')),
    joined_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (guild_id, user_id)  -- one membership per player per guild
);


-- =============================================================================
-- INDEXES
-- Per DATABASE.md index plan
-- =============================================================================

-- trades — active trades inbox for each player
CREATE INDEX idx_trades_initiator_status ON trades (initiator_id, status);
CREATE INDEX idx_trades_receiver_status  ON trades (receiver_id, status);

-- auction_listings — marketplace browse + expiry sweep
CREATE INDEX idx_auction_listings_status_ends ON auction_listings (status, ends_at);

-- notifications — unread badge count
CREATE INDEX idx_notifications_user_unread
    ON notifications (user_id, is_read, created_at);

-- world_event_participants — leaderboard + duplicate prevention
CREATE INDEX idx_world_event_participants_event
    ON world_event_participants (event_id, user_id);

-- guild_members — look up a player's guild
CREATE INDEX idx_guild_members_user ON guild_members (user_id);

-- =============================================================================
-- END V006__phase4_economy_social.sql
-- =============================================================================
