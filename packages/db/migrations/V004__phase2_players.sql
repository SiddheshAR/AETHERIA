-- =============================================================================
-- V004__phase2_players.sql
-- Phase 2: Live Player Data
-- Aetheria — Never edit after apply. Create V005 for any changes.
--
-- KEY RULES FOR THIS PHASE:
--   1. All PKs are UUID — not SERIAL integers
--   2. started_at / ended_at on focus_sessions are SERVER-assigned only
--   3. focus_sessions is PARTITIONED BY MONTH — never retrofit this later
-- =============================================================================

-- =============================================================================
-- 1. users
-- One row per registered player. Central table everything else hangs off.
-- affinity_type_id → type_definitions(type_id)  [V001 PK name]
-- =============================================================================
CREATE TABLE users (
    user_id             UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    username            VARCHAR(32)     NOT NULL UNIQUE,
    email               VARCHAR(255)    NOT NULL UNIQUE,
    password_hash       VARCHAR(255)    NOT NULL,

    -- Type affinity — which type the playe r is aligned with
    affinity_type_id    INTEGER         REFERENCES type_definitions(type_id),

    -- Focus stats (denormalised for fast reads — updated on session end)
    focus_total_minutes INTEGER         NOT NULL DEFAULT 0 CHECK (focus_total_minutes >= 0),
    focus_streak_days   INTEGER         NOT NULL DEFAULT 0 CHECK (focus_streak_days >= 0),
    focus_streak_best   INTEGER         NOT NULL DEFAULT 0 CHECK (focus_streak_best >= 0),

    -- Economy
    currency            INTEGER         NOT NULL DEFAULT 0 CHECK (currency >= 0),

    -- Progression
    prestige_level      SMALLINT        NOT NULL DEFAULT 0 CHECK (prestige_level >= 0),
    title               VARCHAR(50),                        -- e.g. 'Velvet Syndicate Elite'

    -- Customisation
    avatar_config       JSONB,                              -- { "skin": "...", "emblem": "..." }

    created_at          TIMESTAMPTZ     NOT NULL DEFAULT now(),
    last_active         TIMESTAMPTZ     NOT NULL DEFAULT now()
);


-- =============================================================================
-- 2. player_rivals
-- Each player has one auto-generated rival NPC that grows with them.
-- Depends on: users, type_definitions, zones
-- =============================================================================
CREATE TABLE player_rivals (
    rival_id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id               UUID        NOT NULL UNIQUE REFERENCES users(user_id) ON DELETE CASCADE,
    rival_name              VARCHAR(50) NOT NULL,
    speciality_type_id      INTEGER     NOT NULL REFERENCES type_definitions(type_id),
    appearance_config       JSONB,                  -- hair, outfit, colour palette
    current_zone_id         INTEGER     REFERENCES zones(id),
    wins_against_player     INTEGER     NOT NULL DEFAULT 0 CHECK (wins_against_player >= 0),
    losses_to_player        INTEGER     NOT NULL DEFAULT 0 CHECK (losses_to_player >= 0),
    rival_level             SMALLINT    NOT NULL DEFAULT 1 CHECK (rival_level BETWEEN 1 AND 100),
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- =============================================================================
-- 3. sanctuaries
-- Each player owns one sanctuary — a personal space to house Aethers.
-- Passive XP accrues to housed Aethers over time.
-- Depends on: users
-- =============================================================================
CREATE TABLE sanctuaries (
    sanctuary_id    UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id        UUID            NOT NULL UNIQUE REFERENCES users(user_id) ON DELETE CASCADE,
    name            VARCHAR(100)    NOT NULL DEFAULT 'My Sanctuary',
    level           SMALLINT        NOT NULL DEFAULT 1 CHECK (level BETWEEN 1 AND 10),
    capacity        SMALLINT        NOT NULL DEFAULT 6,  -- max Aethers that can be housed
    passive_xp_rate NUMERIC(5,2)    NOT NULL DEFAULT 1.00, -- XP per minute per housed Aether
    is_public       BOOLEAN         NOT NULL DEFAULT FALSE,
    decor_config    JSONB,          -- { "theme": "...", "items": [...] }
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);


-- =============================================================================
-- 4. aether_instances
-- A specific caught/bred Aether belonging to a player.
-- This is the most important live-data table.
-- Self-referencing FKs for parent_1_id / parent_2_id (breeding chain).
-- Unlike aether_species, no second-pass UPDATE needed here —
--   parents always exist before offspring are created at runtime.
-- Depends on: users, aether_species, personality_traits, zones, moves
-- =============================================================================
CREATE TABLE aether_instances (
    instance_id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id            UUID        NOT NULL REFERENCES users(user_id),
    species_id          INTEGER     NOT NULL REFERENCES aether_species(id),
    nickname            VARCHAR(30),

    -- Level & XP
    level               SMALLINT    NOT NULL DEFAULT 1 CHECK (level BETWEEN 1 AND 100),
    current_xp          INTEGER     NOT NULL DEFAULT 0 CHECK (current_xp >= 0),
    current_hp          SMALLINT    NOT NULL CHECK (current_hp >= 0),

    -- Personality
    personality_id      INTEGER     NOT NULL REFERENCES personality_traits(id),

    -- Bond (affects battle performance and evolution)
    bond_level          SMALLINT    NOT NULL DEFAULT 0 CHECK (bond_level BETWEEN 0 AND 10),

    -- Cosmetic variants
    is_shiny            BOOLEAN     NOT NULL DEFAULT FALSE,
    variant_id          SMALLINT    NOT NULL DEFAULT 0,     -- 0 = standard

    -- Individual Values (IVs) — hidden stat modifiers, 0–31 each
    iv_vigor            SMALLINT    NOT NULL DEFAULT 0 CHECK (iv_vigor    BETWEEN 0 AND 31),
    iv_strike           SMALLINT    NOT NULL DEFAULT 0 CHECK (iv_strike   BETWEEN 0 AND 31),
    iv_guard            SMALLINT    NOT NULL DEFAULT 0 CHECK (iv_guard    BETWEEN 0 AND 31),
    iv_aether_atk       SMALLINT    NOT NULL DEFAULT 0 CHECK (iv_aether_atk BETWEEN 0 AND 31),
    iv_ward             SMALLINT    NOT NULL DEFAULT 0 CHECK (iv_ward     BETWEEN 0 AND 31),
    iv_drift            SMALLINT    NOT NULL DEFAULT 0 CHECK (iv_drift    BETWEEN 0 AND 31),

    -- Lineage
    bloodline_tier      SMALLINT    NOT NULL DEFAULT 0 CHECK (bloodline_tier BETWEEN 0 AND 5),
    caught_zone_id      INTEGER     REFERENCES zones(id),
    original_catcher_id UUID        REFERENCES users(user_id),
    generation          SMALLINT    NOT NULL DEFAULT 0,     -- 0 = wild caught, 1+ = bred

    -- Breeding parents (self-referencing — parents exist before offspring)
    parent_1_id         UUID        REFERENCES aether_instances(instance_id),
    parent_2_id         UUID        REFERENCES aether_instances(instance_id),
    has_mutation        BOOLEAN     NOT NULL DEFAULT FALSE,

    -- Active moveset (up to 4 moves equipped)
    move_slot_1         INTEGER     REFERENCES moves(id),
    move_slot_2         INTEGER     REFERENCES moves(id),
    move_slot_3         INTEGER     REFERENCES moves(id),
    move_slot_4         INTEGER     REFERENCES moves(id),

    -- Location flags
    in_party            BOOLEAN     NOT NULL DEFAULT FALSE,
    in_sanctuary        BOOLEAN     NOT NULL DEFAULT FALSE,

    -- Awakening (post-max-level power system)
    awakening_stage     SMALLINT    NOT NULL DEFAULT 0 CHECK (awakening_stage BETWEEN 0 AND 3),

    -- Trade history log
    trade_history       JSONB       NOT NULL DEFAULT '[]',

    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- An Aether can only be in one place at a time
    CHECK (NOT (in_party = TRUE AND in_sanctuary = TRUE))
);


-- =============================================================================
-- 5. sanctuary_housing
-- Junction: which Aether instances are currently housed in which sanctuary.
-- Passive XP tracked here per instance.
-- Depends on: sanctuaries, aether_instances
-- =============================================================================
CREATE TABLE sanctuary_housing (
    housing_id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    sanctuary_id        UUID        NOT NULL REFERENCES sanctuaries(sanctuary_id) ON DELETE CASCADE,
    instance_id         UUID        NOT NULL UNIQUE REFERENCES aether_instances(instance_id),
    placed_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    xp_accumulated      INTEGER     NOT NULL DEFAULT 0 CHECK (xp_accumulated >= 0),
    last_collected_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (sanctuary_id, instance_id)
);


-- =============================================================================
-- 6. focus_sessions
-- One row per completed or abandoned focus session.
-- PARTITIONED BY RANGE (started_at) — monthly partitions.
-- This table grows fast. Partitioning must be set up from day one.
--
-- ANTI-CHEAT: started_at and ended_at are NEVER set by the client.
--   Backend sets started_at on POST /session/start
--   Backend sets ended_at on POST /session/end
--   duration_minutes is computed server-side from (ended_at - started_at)
--
-- NOTE: PostgreSQL requires the partition key (started_at) to be
--   part of the PRIMARY KEY on partitioned tables.
-- Depends on: users, aether_instances, subject_type_mappings
-- =============================================================================
CREATE TABLE focus_sessions (
    session_id          UUID        NOT NULL DEFAULT gen_random_uuid(),
    user_id             UUID        NOT NULL REFERENCES users(user_id),

    -- Server-assigned timestamps only — never trust client
    started_at          TIMESTAMPTZ NOT NULL,
    ended_at            TIMESTAMPTZ,            -- NULL while session is active

    duration_minutes    SMALLINT    CHECK (duration_minutes IS NULL OR duration_minutes BETWEEN 0 AND 240),
    subject_tag         VARCHAR(40) REFERENCES subject_type_mappings(subject_tag),
    completed           BOOLEAN     NOT NULL DEFAULT FALSE,

    -- Anti-cheat tracking
    distraction_events  SMALLINT    NOT NULL DEFAULT 0 CHECK (distraction_events >= 0),
    is_flagged          BOOLEAN     NOT NULL DEFAULT FALSE, -- server flagged as suspicious

    -- Rewards (computed on session end)
    reward_tier         SMALLINT    CHECK (reward_tier BETWEEN 1 AND 5),
    xp_awarded          INTEGER     NOT NULL DEFAULT 0 CHECK (xp_awarded >= 0),
    items_found         JSONB       NOT NULL DEFAULT '[]', -- [{ item_code, quantity }]

    -- Which Aether was being trained
    trained_instance_id UUID        REFERENCES aether_instances(instance_id),

    -- Partition key must be in PK for partitioned tables
    PRIMARY KEY (session_id, started_at)
) PARTITION BY RANGE (started_at);

-- Default partition — catches anything outside explicit monthly partitions
-- Always keep this so inserts never fail due to missing partition
CREATE TABLE focus_sessions_default
    PARTITION OF focus_sessions DEFAULT;

-- Initial monthly partitions (add new ones monthly via a cron job or migration)
CREATE TABLE focus_sessions_2025_01 PARTITION OF focus_sessions
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE focus_sessions_2025_02 PARTITION OF focus_sessions
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');
CREATE TABLE focus_sessions_2025_03 PARTITION OF focus_sessions
    FOR VALUES FROM ('2025-03-01') TO ('2025-04-01');
CREATE TABLE focus_sessions_2025_04 PARTITION OF focus_sessions
    FOR VALUES FROM ('2025-04-01') TO ('2025-05-01');
CREATE TABLE focus_sessions_2025_05 PARTITION OF focus_sessions
    FOR VALUES FROM ('2025-05-01') TO ('2025-06-01');
CREATE TABLE focus_sessions_2025_06 PARTITION OF focus_sessions
    FOR VALUES FROM ('2025-06-01') TO ('2025-07-01');
CREATE TABLE focus_sessions_2025_07 PARTITION OF focus_sessions
    FOR VALUES FROM ('2025-07-01') TO ('2025-08-01');
CREATE TABLE focus_sessions_2025_08 PARTITION OF focus_sessions
    FOR VALUES FROM ('2025-08-01') TO ('2025-09-01');
CREATE TABLE focus_sessions_2025_09 PARTITION OF focus_sessions
    FOR VALUES FROM ('2025-09-01') TO ('2025-10-01');
CREATE TABLE focus_sessions_2025_10 PARTITION OF focus_sessions
    FOR VALUES FROM ('2025-10-01') TO ('2025-11-01');
CREATE TABLE focus_sessions_2025_11 PARTITION OF focus_sessions
    FOR VALUES FROM ('2025-11-01') TO ('2025-12-01');
CREATE TABLE focus_sessions_2025_12 PARTITION OF focus_sessions
    FOR VALUES FROM ('2025-12-01') TO ('2026-01-01');
CREATE TABLE focus_sessions_2026_01 PARTITION OF focus_sessions
    FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');
CREATE TABLE focus_sessions_2026_02 PARTITION OF focus_sessions
    FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');
CREATE TABLE focus_sessions_2026_03 PARTITION OF focus_sessions
    FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');
CREATE TABLE focus_sessions_2026_04 PARTITION OF focus_sessions
    FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');
CREATE TABLE focus_sessions_2026_06 PARTITION OF focus_sessions
    FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE focus_sessions_2026_07 PARTITION OF focus_sessions
    FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE focus_sessions_2026_08 PARTITION OF focus_sessions
    FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE focus_sessions_2026_09 PARTITION OF focus_sessions
    FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE focus_sessions_2026_10 PARTITION OF focus_sessions
    FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');
CREATE TABLE focus_sessions_2026_11 PARTITION OF focus_sessions
    FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
CREATE TABLE focus_sessions_2026_12 PARTITION OF focus_sessions
    FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');


-- =============================================================================
-- 7. player_inventory
-- Items owned by a player.
-- Depends on: users, item_definitions
-- =============================================================================
CREATE TABLE player_inventory (
    inventory_id    UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID        NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    item_id         INTEGER     NOT NULL REFERENCES item_definitions(id),
    quantity        INTEGER     NOT NULL DEFAULT 1 CHECK (quantity > 0),
    obtained_from   VARCHAR(50),    -- 'FOCUS_SESSION', 'PURCHASE', 'QUEST_REWARD', 'TRADE'
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, item_id)       -- one row per item type per player, quantity stacks
);


-- =============================================================================
-- 8. player_quest_progress
-- Tracks each player's progress through every quest they've started.
-- Depends on: users, quests, quest_stages
-- =============================================================================
CREATE TABLE player_quest_progress (
    progress_id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id           UUID        NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    quest_id            INTEGER     NOT NULL REFERENCES quests(id),
    current_stage_id    INTEGER     REFERENCES quest_stages(id),
    status              VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
                            CHECK (status IN ('ACTIVE', 'COMPLETED', 'FAILED', 'ABANDONED')),
    started_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at        TIMESTAMPTZ,
    UNIQUE (player_id, quest_id)    -- one progress row per quest per player
);


-- =============================================================================
-- 9. player_world_flags
-- Key-value store of world state flags per player per zone.
-- Written by quest_stage_outcomes. Read by quest_unlock_conditions.
-- Depends on: users, zones
-- =============================================================================
CREATE TABLE player_world_flags (
    pflag_id    UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id   UUID        NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    zone_id     INTEGER     REFERENCES zones(id),
    flag_key    VARCHAR(60) NOT NULL,
    flag_value  VARCHAR(50) NOT NULL,
    set_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (player_id, flag_key)    -- one value per flag per player
);


-- =============================================================================
-- 10. player_boss_defeats
-- Records each boss a player has defeated, and how many attempts it took.
-- Depends on: users, zone_bosses
-- =============================================================================
CREATE TABLE player_boss_defeats (
    defeat_id   UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id   UUID        NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    boss_id     INTEGER     NOT NULL REFERENCES zone_bosses(id),
    defeated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    attempts    SMALLINT    NOT NULL DEFAULT 1 CHECK (attempts > 0),
    UNIQUE (player_id, boss_id)     -- one row per boss per player (can't defeat twice)
);


-- =============================================================================
-- 11. player_reputation
-- Reputation score per player per faction. Drives rank names and NPC dialogue.
-- Depends on: users, factions
-- =============================================================================
CREATE TABLE player_reputation (
    rep_id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id           UUID        NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    faction_id          INTEGER     NOT NULL REFERENCES factions(id),
    reputation_score    INTEGER     NOT NULL DEFAULT 0,
    -- Score thresholds (app layer):
    --   0–99   = rank 0 (Outsider)
    --   100–299 = rank 1
    --   300–599 = rank 2
    --   600–999 = rank 3
    --   1000+   = rank 4 (Elite)
    last_changed_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (player_id, faction_id)
);


-- =============================================================================
-- 12. player_progression
-- Tracks which zones a player has unlocked and completed.
-- Depends on: users, zones
-- =============================================================================
CREATE TABLE player_progression (
    progression_id  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id       UUID        NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    zone_id         INTEGER     NOT NULL REFERENCES zones(id),
    is_unlocked     BOOLEAN     NOT NULL DEFAULT FALSE,
    is_completed    BOOLEAN     NOT NULL DEFAULT FALSE,
    unlocked_at     TIMESTAMPTZ,
    completed_at    TIMESTAMPTZ,
    UNIQUE (player_id, zone_id)
);


-- =============================================================================
-- INDEXES
-- Added here per DATABASE.md index plan.
-- =============================================================================

-- aether_instances — most frequent query: party screen
CREATE INDEX idx_aether_instances_owner_party
    ON aether_instances (owner_id, species_id, in_party);

-- focus_sessions — session history + streak calculation
-- Note: indexes on partitioned tables apply to all partitions automatically
CREATE INDEX idx_focus_sessions_user_started
    ON focus_sessions (user_id, started_at, completed);

-- player_world_flags — quest condition checks
CREATE INDEX idx_player_world_flags_lookup
    ON player_world_flags (player_id, zone_id, flag_key);

-- player_quest_progress — quest log screen
CREATE INDEX idx_player_quest_progress_status
    ON player_quest_progress (player_id, status);

-- player_reputation — NPC interaction rep checks
CREATE INDEX idx_player_reputation_lookup
    ON player_reputation (player_id, faction_id);

-- =============================================================================
-- END V004__phase2_players.sql
-- =============================================================================
