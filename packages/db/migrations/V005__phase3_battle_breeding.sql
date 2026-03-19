-- =============================================================================
-- V005__phase3_battle_breeding.sql
-- Phase 3: Battle, Breeding & Awakening
-- Aetheria — Never edit after apply. Create V006 for any changes.
--
-- KEY RULES FOR THIS PHASE:
--   1. battle_turn_logs is PARTITIONED BY MONTH — same as focus_sessions
--   2. Battle state (HP, status, turn) lives in Redis during a live battle
--      Only the final summary and full turn log are written to Postgres
--   3. Damage formula lives in app code — not in DB
-- =============================================================================

-- =============================================================================
-- 1. battles
-- One row per completed battle. Live battle state is in Redis.
-- battle_type: WILD = player vs wild Aether, PVP = player vs player,
--              BOSS = player vs zone boss, RIVAL = player vs rival NPC
-- Depends on: users, zones, weather_definitions
-- =============================================================================
CREATE TABLE battles (
    battle_id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    battle_type         VARCHAR(10) NOT NULL
                            CHECK (battle_type IN ('WILD', 'PVP', 'BOSS', 'RIVAL')),

    -- Players (player_2_id is NULL for WILD battles)
    player_1_id         UUID        NOT NULL REFERENCES users(user_id),
    player_2_id         UUID        REFERENCES users(user_id),
    winner_id           UUID        REFERENCES users(user_id),

    -- Context
    zone_id             INTEGER     REFERENCES zones(id),
    weather_id          INTEGER     REFERENCES weather_definitions(id),
    time_period         VARCHAR(10) CHECK (time_period IN ('DAY', 'NIGHT', 'DAWN', 'DUSK')),

    -- Timing
    started_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    ended_at            TIMESTAMPTZ,

    -- Rewards (awarded to winner on battle end)
    xp_awarded          INTEGER     NOT NULL DEFAULT 0 CHECK (xp_awarded >= 0),
    currency_awarded    INTEGER     NOT NULL DEFAULT 0 CHECK (currency_awarded >= 0),

    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- =============================================================================
-- 2. battle_turn_logs
-- One row per action taken in a battle. Grows extremely fast.
-- PARTITIONED BY RANGE (created_at) — monthly partitions.
--
-- Live battle state (HP, status effects, turn order) lives in Redis.
-- These rows are written at battle END for replay and analytics only.
-- Depends on: battles, aether_instances, moves
-- =============================================================================
CREATE TABLE battle_turn_logs (
    log_id              UUID        NOT NULL DEFAULT gen_random_uuid(),
    battle_id           UUID        NOT NULL REFERENCES battles(battle_id),
    turn_number         SMALLINT    NOT NULL CHECK (turn_number > 0),
    acting_instance_id  UUID        NOT NULL REFERENCES aether_instances(instance_id),
    action_type         VARCHAR(20) NOT NULL
                            CHECK (action_type IN (
                                'MOVE',     -- used a move
                                'SWITCH',   -- switched Aether
                                'ITEM',     -- used an item
                                'FLEE',     -- attempted to flee
                                'CATCH'     -- attempted to catch
                            )),
    move_id             INTEGER     REFERENCES moves(id),   -- NULL if action_type != MOVE
    damage_dealt        SMALLINT    NOT NULL DEFAULT 0 CHECK (damage_dealt >= 0),
    type_multiplier     NUMERIC(4,2) NOT NULL DEFAULT 1.00,
    is_critical         BOOLEAN     NOT NULL DEFAULT FALSE,
    status_applied      VARCHAR(30),                        -- status_code applied this turn

    -- Partition key — must be in PK
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (log_id, created_at)
) PARTITION BY RANGE (created_at);

-- Default partition — safety net for any dates outside explicit partitions
CREATE TABLE battle_turn_logs_default
    PARTITION OF battle_turn_logs DEFAULT;

-- Monthly partitions (add new ones each month via cron job or new migration)
CREATE TABLE battle_turn_logs_2025_01 PARTITION OF battle_turn_logs
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE battle_turn_logs_2025_02 PARTITION OF battle_turn_logs
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');
CREATE TABLE battle_turn_logs_2025_03 PARTITION OF battle_turn_logs
    FOR VALUES FROM ('2025-03-01') TO ('2025-04-01');
CREATE TABLE battle_turn_logs_2025_04 PARTITION OF battle_turn_logs
    FOR VALUES FROM ('2025-04-01') TO ('2025-05-01');
CREATE TABLE battle_turn_logs_2025_05 PARTITION OF battle_turn_logs
    FOR VALUES FROM ('2025-05-01') TO ('2025-06-01');
CREATE TABLE battle_turn_logs_2025_06 PARTITION OF battle_turn_logs
    FOR VALUES FROM ('2025-06-01') TO ('2025-07-01');
CREATE TABLE battle_turn_logs_2025_07 PARTITION OF battle_turn_logs
    FOR VALUES FROM ('2025-07-01') TO ('2025-08-01');
CREATE TABLE battle_turn_logs_2025_08 PARTITION OF battle_turn_logs
    FOR VALUES FROM ('2025-08-01') TO ('2025-09-01');
CREATE TABLE battle_turn_logs_2025_09 PARTITION OF battle_turn_logs
    FOR VALUES FROM ('2025-09-01') TO ('2025-10-01');
CREATE TABLE battle_turn_logs_2025_10 PARTITION OF battle_turn_logs
    FOR VALUES FROM ('2025-10-01') TO ('2025-11-01');
CREATE TABLE battle_turn_logs_2025_11 PARTITION OF battle_turn_logs
    FOR VALUES FROM ('2025-11-01') TO ('2025-12-01');
CREATE TABLE battle_turn_logs_2025_12 PARTITION OF battle_turn_logs
    FOR VALUES FROM ('2025-12-01') TO ('2026-01-01');
CREATE TABLE battle_turn_logs_2026_01 PARTITION OF battle_turn_logs
    FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');
CREATE TABLE battle_turn_logs_2026_02 PARTITION OF battle_turn_logs
    FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');
CREATE TABLE battle_turn_logs_2026_03 PARTITION OF battle_turn_logs
    FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');
CREATE TABLE battle_turn_logs_2026_04 PARTITION OF battle_turn_logs
    FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');
CREATE TABLE battle_turn_logs_2026_05 PARTITION OF battle_turn_logs
    FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');
CREATE TABLE battle_turn_logs_2026_06 PARTITION OF battle_turn_logs
    FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE battle_turn_logs_2026_07 PARTITION OF battle_turn_logs
    FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE battle_turn_logs_2026_08 PARTITION OF battle_turn_logs
    FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE battle_turn_logs_2026_09 PARTITION OF battle_turn_logs
    FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE battle_turn_logs_2026_10 PARTITION OF battle_turn_logs
    FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');
CREATE TABLE battle_turn_logs_2026_11 PARTITION OF battle_turn_logs
    FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
CREATE TABLE battle_turn_logs_2026_12 PARTITION OF battle_turn_logs
    FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');

-- Index on battle_id for replay queries (fetch all turns of a battle)
CREATE INDEX idx_battle_turn_logs_battle_id
    ON battle_turn_logs (battle_id);


-- =============================================================================
-- 3. awakening_challenges
-- Static config: species-specific challenges required to advance awakening stage.
-- SERIAL PK (static data, like V002 tables).
-- Each species has up to 3 stages, each with its own challenge.
-- Depends on: aether_species
-- =============================================================================
CREATE TABLE awakening_challenges (
    id                  SERIAL      PRIMARY KEY,
    species_id          INTEGER     NOT NULL REFERENCES aether_species(id),
    stage               SMALLINT    NOT NULL CHECK (stage BETWEEN 1 AND 3),
    challenge_type      VARCHAR(30) NOT NULL
                            CHECK (challenge_type IN (
                                'WIN_BATTLES',      -- win N battles with this Aether
                                'FOCUS_SESSIONS',   -- complete N focus sessions with it trained
                                'CATCH_SPECIES',    -- catch N of a specific species
                                'BOND_LEVEL',       -- reach a bond level
                                'USE_MOVE',         -- use a specific move N times
                                'STREAK_DAYS'       -- maintain N day streak
                            )),
    challenge_target    VARCHAR(50) NOT NULL,   -- e.g. '20' for count, 'SHADOW_SLASH' for move
    description         TEXT        NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (species_id, stage)                  -- one challenge per stage per species
);

-- Seed awakening challenges for starter lines
INSERT INTO awakening_challenges (species_id, stage, challenge_type, challenge_target, description)
VALUES
    -- Nocterion awakening
    ((SELECT id FROM aether_species WHERE species_code = 'NOCTERION'), 1,
     'WIN_BATTLES',    '20',          'Win 20 battles with Nocterion in your party.'),
    ((SELECT id FROM aether_species WHERE species_code = 'NOCTERION'), 2,
     'FOCUS_SESSIONS', '10',          'Complete 10 focus sessions with Nocterion as your trained Aether.'),
    ((SELECT id FROM aether_species WHERE species_code = 'NOCTERION'), 3,
     'USE_MOVE',       'VOID_SHROUD', 'Use Void Shroud 30 times in battle.'),

    -- Solarius X awakening
    ((SELECT id FROM aether_species WHERE species_code = 'SOLARIUS_X'), 1,
     'WIN_BATTLES',    '20',          'Win 20 battles with Solarius X in your party.'),
    ((SELECT id FROM aether_species WHERE species_code = 'SOLARIUS_X'), 2,
     'STREAK_DAYS',    '14',          'Maintain a 14-day focus streak while Solarius X is in your party.'),
    ((SELECT id FROM aether_species WHERE species_code = 'SOLARIUS_X'), 3,
     'USE_MOVE',       'SOLAR_FLARE', 'Use Solar Flare 30 times in battle.'),

    -- Grandluxe awakening
    ((SELECT id FROM aether_species WHERE species_code = 'GRANDLUXE'), 1,
     'WIN_BATTLES',    '20',          'Win 20 battles with Grandluxe in your party.'),
    ((SELECT id FROM aether_species WHERE species_code = 'GRANDLUXE'), 2,
     'BOND_LEVEL',     '8',           'Reach bond level 8 with Grandluxe.'),
    ((SELECT id FROM aether_species WHERE species_code = 'GRANDLUXE'), 3,
     'FOCUS_SESSIONS', '15',          'Complete 15 focus sessions with Grandluxe as your trained Aether.'),

    -- Ironhide awakening
    ((SELECT id FROM aether_species WHERE species_code = 'IRONHIDE'), 1,
     'WIN_BATTLES',    '15',          'Win 15 battles with Ironhide in your party.'),
    ((SELECT id FROM aether_species WHERE species_code = 'IRONHIDE'), 2,
     'USE_MOVE',       'IRON_DEFENSE','Use Iron Defense 20 times in battle.'),
    ((SELECT id FROM aether_species WHERE species_code = 'IRONHIDE'), 3,
     'FOCUS_SESSIONS', '10',          'Complete 10 focus sessions with Ironhide as your trained Aether.'),

    -- Aurath awakening
    ((SELECT id FROM aether_species WHERE species_code = 'AURATH'), 1,
     'FOCUS_SESSIONS', '10',          'Complete 10 focus sessions with Aurath as your trained Aether.'),
    ((SELECT id FROM aether_species WHERE species_code = 'AURATH'), 2,
     'STREAK_DAYS',    '7',           'Maintain a 7-day focus streak with Aurath in your party.'),
    ((SELECT id FROM aether_species WHERE species_code = 'AURATH'), 3,
     'BOND_LEVEL',     '9',           'Reach bond level 9 with Aurath.');


-- =============================================================================
-- 4. awakening_records
-- Live tracking of a specific instance's awakening progress.
-- One row per instance that has started awakening.
-- challenge_progress is a JSONB snapshot of current challenge counts.
-- Depends on: aether_instances
-- =============================================================================
CREATE TABLE awakening_records (
    awakening_id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    instance_id             UUID        NOT NULL UNIQUE REFERENCES aether_instances(instance_id)
                                        ON DELETE CASCADE,
    current_stage           SMALLINT    NOT NULL DEFAULT 0 CHECK (current_stage BETWEEN 0 AND 3),

    -- Live progress snapshot — updated as player completes challenge actions
    -- e.g. { "WIN_BATTLES": 12, "FOCUS_SESSIONS": 3 }
    challenge_progress      JSONB       NOT NULL DEFAULT '{}',

    -- Stage completion timestamps (NULL = not yet completed)
    stage_1_completed_at    TIMESTAMPTZ,
    stage_2_completed_at    TIMESTAMPTZ,
    stage_3_completed_at    TIMESTAMPTZ,

    created_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- =============================================================================
-- 5. breeding_records
-- Tracks an active or completed breeding pair.
-- hatch_ready_at is server-computed based on species + location_bonus.
-- offspring_instance_id is NULL until the egg hatches.
-- Depends on: aether_instances, users, aether_species
-- =============================================================================
CREATE TABLE breeding_records (
    breeding_id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_1_id             UUID        NOT NULL REFERENCES aether_instances(instance_id),
    parent_2_id             UUID        NOT NULL REFERENCES aether_instances(instance_id),
    owner_id                UUID        NOT NULL REFERENCES users(user_id),

    started_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    hatch_ready_at          TIMESTAMPTZ NOT NULL,   -- server-computed, never client

    -- Bonus if bred in matching zone type affinity
    location_bonus          BOOLEAN     NOT NULL DEFAULT FALSE,

    -- Determined on breeding start, revealed on hatch
    egg_species_id          INTEGER     NOT NULL REFERENCES aether_species(id),

    is_hatched              BOOLEAN     NOT NULL DEFAULT FALSE,
    offspring_instance_id   UUID        REFERENCES aether_instances(instance_id),

    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),

    CHECK (parent_1_id != parent_2_id)  -- can't breed with itself
);


-- =============================================================================
-- 6. breeding_mutations
-- Records any mutations that occurred on a bred instance.
-- A mutation is a rare random bonus stat or trait deviation.
-- Depends on: aether_instances
-- =============================================================================
CREATE TABLE breeding_mutations (
    mutation_id     UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    instance_id     UUID        NOT NULL REFERENCES aether_instances(instance_id)
                                ON DELETE CASCADE,
    mutation_type   VARCHAR(30) NOT NULL
                        CHECK (mutation_type IN (
                            'STAT_BOOST',       -- one base stat increased
                            'IV_PERFECT',       -- one IV forced to 31
                            'TYPE_SHIFT',       -- secondary type changes
                            'MOVE_INHERIT',     -- inherits a parent move outside normal learnset
                            'SHINY_FORCE',      -- forced shiny regardless of normal rate
                            'BLOODLINE_UP'      -- bloodline_tier increased by 1
                        )),
    mutation_value  TEXT        NOT NULL,   -- e.g. 'base_strike', 'iv_vigor', 'SHADOW_SLASH'
    triggered_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- =============================================================================
-- INDEXES
-- =============================================================================

-- battles — look up a player's battle history
CREATE INDEX idx_battles_player_1 ON battles (player_1_id, started_at);
CREATE INDEX idx_battles_player_2 ON battles (player_2_id, started_at);

-- awakening_records — check if an instance has an awakening record
CREATE INDEX idx_awakening_records_instance ON awakening_records (instance_id);

-- breeding_records — active breeding check per owner
CREATE INDEX idx_breeding_records_owner ON breeding_records (owner_id, is_hatched);

-- =============================================================================
-- END V005__phase3_battle_breeding.sql
-- =============================================================================
