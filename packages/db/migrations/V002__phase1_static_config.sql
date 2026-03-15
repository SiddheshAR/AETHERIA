-- =============================================================================
-- V002__phase1_static_config.sql
-- Phase 1: Static Configuration Tables
-- Aetheria — Never edit after apply. Create V003 for any changes.
-- =============================================================================

-- =============================================================================
-- 1. personality_traits
-- Personality assigned to an Aether on capture.
-- Shape: boosted_stat / reduced_stat (varchar) + boost_pct / reduce_pct (decimal)
-- No dependencies.
-- =============================================================================
CREATE TABLE personality_traits (
    id              SERIAL          PRIMARY KEY,
    trait_code      VARCHAR(20)     NOT NULL UNIQUE,
    display_name    VARCHAR(50)     NOT NULL,
    boosted_stat    VARCHAR(20),                        -- NULL = neutral
    reduced_stat    VARCHAR(20),                        -- NULL = neutral
    boost_pct       NUMERIC(5,2)    NOT NULL DEFAULT 0.00,
    reduce_pct      NUMERIC(5,2)    NOT NULL DEFAULT 0.00,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CHECK (
        (boosted_stat IS NULL AND reduced_stat IS NULL AND boost_pct = 0 AND reduce_pct = 0)
        OR
        (boosted_stat IS NOT NULL AND reduced_stat IS NOT NULL AND boost_pct > 0 AND reduce_pct > 0)
    )
);

INSERT INTO personality_traits
    (trait_code, display_name, boosted_stat, reduced_stat, boost_pct, reduce_pct)
VALUES
    -- +Strike (Atk)
    ('LONELY',   'Lonely',   'base_strike',    'base_guard',      10.00, 10.00),
    ('BRAVE',    'Brave',    'base_strike',    'base_drift',      10.00, 10.00),
    ('ADAMANT',  'Adamant',  'base_strike',    'base_aether_atk', 10.00, 10.00),
    ('NAUGHTY',  'Naughty',  'base_strike',    'base_ward',       10.00, 10.00),
    -- +Guard (Def)
    ('BOLD',     'Bold',     'base_guard',     'base_strike',     10.00, 10.00),
    ('RELAXED',  'Relaxed',  'base_guard',     'base_drift',      10.00, 10.00),
    ('IMPISH',   'Impish',   'base_guard',     'base_aether_atk', 10.00, 10.00),
    ('LAX',      'Lax',      'base_guard',     'base_ward',       10.00, 10.00),
    -- +Aether Atk (Sp.Atk)
    ('MODEST',   'Modest',   'base_aether_atk','base_strike',     10.00, 10.00),
    ('MILD',     'Mild',     'base_aether_atk','base_guard',      10.00, 10.00),
    ('QUIET',    'Quiet',    'base_aether_atk','base_drift',      10.00, 10.00),
    ('RASH',     'Rash',     'base_aether_atk','base_ward',       10.00, 10.00),
    -- +Ward (Sp.Def)
    ('CALM',     'Calm',     'base_ward',      'base_strike',     10.00, 10.00),
    ('GENTLE',   'Gentle',   'base_ward',      'base_guard',      10.00, 10.00),
    ('SASSY',    'Sassy',    'base_ward',      'base_drift',      10.00, 10.00),
    ('CAREFUL',  'Careful',  'base_ward',      'base_aether_atk', 10.00, 10.00),
    -- +Drift (Spd)
    ('TIMID',    'Timid',    'base_drift',     'base_strike',     10.00, 10.00),
    ('HASTY',    'Hasty',    'base_drift',     'base_guard',      10.00, 10.00),
    ('JOLLY',    'Jolly',    'base_drift',     'base_aether_atk', 10.00, 10.00),
    ('NAIVE',    'Naive',    'base_drift',     'base_ward',       10.00, 10.00),
    -- Neutral
    ('HARDY',    'Hardy',    NULL, NULL, 0.00, 0.00),
    ('DOCILE',   'Docile',   NULL, NULL, 0.00, 0.00),
    ('SERIOUS',  'Serious',  NULL, NULL, 0.00, 0.00),
    ('BASHFUL',  'Bashful',  NULL, NULL, 0.00, 0.00),
    ('QUIRKY',   'Quirky',   NULL, NULL, 0.00, 0.00);


-- =============================================================================
-- 2. status_definitions
-- Shape: structured columns matching DATABASE.md
--   hp_drain_pct, stat_affected, stat_modifier_pct,
--   skip_turn_chance_pct, min_duration_turns, max_duration_turns
-- No dependencies.
-- =============================================================================
CREATE TABLE status_definitions (
    id                      SERIAL          PRIMARY KEY,
    status_code             VARCHAR(30)     NOT NULL UNIQUE,
    display_name            VARCHAR(50)     NOT NULL,
    category                VARCHAR(20)     NOT NULL
                                CHECK (category IN ('VOLATILE', 'NON_VOLATILE', 'FIELD')),
    description             TEXT,
    hp_drain_pct            NUMERIC(5,2)    NOT NULL DEFAULT 0.00,
    stat_affected           VARCHAR(20),
    stat_modifier_pct       NUMERIC(6,2)    NOT NULL DEFAULT 0.00,  -- negative = debuff
    skip_turn_chance_pct    SMALLINT        NOT NULL DEFAULT 0,
    min_duration_turns      SMALLINT        NOT NULL DEFAULT 1,
    max_duration_turns      SMALLINT        NOT NULL DEFAULT 1,     -- 999 = indefinite
    is_positive             BOOLEAN         NOT NULL DEFAULT FALSE,
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT now()
);

INSERT INTO status_definitions
    (status_code, display_name, category, description,
     hp_drain_pct, stat_affected, stat_modifier_pct, skip_turn_chance_pct,
     min_duration_turns, max_duration_turns, is_positive)
VALUES
    -- Non-volatile
    ('BURN',        'Burn',       'NON_VOLATILE', 'Loses HP each turn. Strike halved.',
        6.25,  'base_strike',   -50.00, 0,   999, 999, FALSE),
    ('PARALYSIS',   'Paralysis',  'NON_VOLATILE', 'May lose turn. Drift quartered.',
        0.00,  'base_drift',    -75.00, 25,  999, 999, FALSE),
    ('POISON',      'Poison',     'NON_VOLATILE', 'Loses 12.5% HP per turn.',
        12.50, NULL,              0.00, 0,   999, 999, FALSE),
    ('BAD_POISON',  'Bad Poison', 'NON_VOLATILE', 'HP loss increases each turn.',
        6.25,  NULL,              0.00, 0,   999, 999, FALSE),
    ('FREEZE',      'Freeze',     'NON_VOLATILE', 'Cannot act. 20% thaw chance per turn.',
        0.00,  NULL,              0.00, 100,   1,   5, FALSE),
    ('SLEEP',       'Sleep',      'NON_VOLATILE', 'Cannot act for 1–3 turns.',
        0.00,  NULL,              0.00, 100,   1,   3, FALSE),
    -- Volatile
    ('CONFUSED',    'Confused',   'VOLATILE', 'May hurt itself. Clears on switch.',
        0.00,  NULL,    0.00, 33, 1,  4, FALSE),
    ('FLINCH',      'Flinch',     'VOLATILE', 'Loses action this turn only.',
        0.00,  NULL,    0.00, 100, 1, 1, FALSE),
    ('CURSED',      'Cursed',     'VOLATILE', 'Loses 25% HP per turn.',
        25.00, NULL,    0.00,  0, 999, 999, FALSE),
    ('BOUND',       'Bound',      'VOLATILE', 'Trapped. Damaged each turn for 2–5 turns.',
        12.50, NULL,    0.00,  0,  2,   5, FALSE),
    ('INFATUATED',  'Infatuated', 'VOLATILE', '50% chance to be unable to attack.',
        0.00,  NULL,    0.00, 50,  1,   5, FALSE),
    ('TAUNT',       'Taunt',      'VOLATILE', 'Can only use damaging moves.',
        0.00,  NULL,    0.00,  0,  3,   3, FALSE),
    -- Positive
    ('FOCUS_BOOST', 'Focus Boost','VOLATILE', 'Earned from focus sessions. Boosts all stats.',
        0.00,  NULL,    0.00,  0, 999, 999, TRUE),
    ('PROTECTED',   'Protected',  'VOLATILE', 'Immune to damage this turn.',
        0.00,  NULL,    0.00,  0,   1,   1, TRUE),
    ('CHARGED',     'Charged',    'VOLATILE', 'Next Rave move deals double damage.',
        0.00,  NULL,    0.00,  0,   1,   1, TRUE),
    -- Field
    ('REFLECT',      'Reflect',      'FIELD', 'Halves physical damage for the team.',
        0.00, NULL,    0.00, 0, 5, 5, TRUE),
    ('LIGHT_SCREEN', 'Light Screen', 'FIELD', 'Halves special damage for the team.',
        0.00, NULL,    0.00, 0, 5, 5, TRUE),
    ('TAILWIND',     'Tailwind',     'FIELD', 'Doubles Drift for team for 4 turns.',
        0.00, 'base_drift', 100.00, 0, 4, 4, TRUE),
    ('TRICK_ROOM',   'Trick Room',   'FIELD', 'Slower Aethers move first for 5 turns.',
        0.00, NULL,    0.00, 0, 5, 5, FALSE);


-- =============================================================================
-- 3. streak_milestones
-- No dependencies.
-- =============================================================================
CREATE TABLE streak_milestones (
    id                  SERIAL          PRIMARY KEY,
    streak_days         INTEGER         NOT NULL UNIQUE CHECK (streak_days > 0),
    milestone_label     VARCHAR(100)    NOT NULL,
    reward_description  TEXT,
    bonus_exp_pct       NUMERIC(5,2)    NOT NULL DEFAULT 0.00,
    bonus_shiny_chance  NUMERIC(6,4)    NOT NULL DEFAULT 0.0000,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT now()
);

INSERT INTO streak_milestones
    (streak_days, milestone_label, reward_description, bonus_exp_pct, bonus_shiny_chance)
VALUES
    (3,   '3-Day Streak',   'First milestone — keep going!',             5.00,  0.0010),
    (7,   '7-Day Streak',   'One week strong. Rare spawn boost.',        10.00,  0.0025),
    (14,  '14-Day Streak',  'Two weeks! Shiny chance increases.',        15.00,  0.0050),
    (21,  '21-Day Streak',  'Habit locked in. Epic spawn bonus.',        20.00,  0.0075),
    (30,  '30-Day Streak',  'One month. Ancient Aether possible.',       30.00,  0.0100),
    (60,  '60-Day Streak',  'Two months. Legendary pool unlocked.',      40.00,  0.0150),
    (100, '100-Day Streak', 'Elite Binder. Max shiny boost active.',     50.00,  0.0200),
    (365, '365-Day Streak', 'Aetheria Legend. God-tier encounters.',    100.00,  0.0500);


-- =============================================================================
-- 4. zones
-- Shape per DATABASE.md: tilemap_key, is_legendary_zone, is_god_zone
-- No dependencies.
-- =============================================================================
CREATE TABLE zones (
    id                  SERIAL          PRIMARY KEY,
    zone_code           VARCHAR(30)     NOT NULL UNIQUE,
    display_name        VARCHAR(100)    NOT NULL,
    description         TEXT,
    unlock_level        SMALLINT        NOT NULL DEFAULT 1,
    tilemap_key         VARCHAR(50),
    is_starter_zone     BOOLEAN         NOT NULL DEFAULT FALSE,
    is_legendary_zone   BOOLEAN         NOT NULL DEFAULT FALSE,
    is_god_zone         BOOLEAN         NOT NULL DEFAULT FALSE,
    ambient_theme       VARCHAR(50),
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT now()
);

INSERT INTO zones
    (zone_code, display_name, description, unlock_level, tilemap_key, is_starter_zone, is_legendary_zone, is_god_zone, ambient_theme)
VALUES
    ('VELVET_DISTRICT',  'Velvet District',  'A glamorous urban sprawl. Fashion-forward Aethers roam the boutiques.',   1,  'map_velvet',   TRUE,  FALSE, FALSE, 'urban_night'),
    ('SOLEIL_COAST',     'Soleil Coast',     'Sun-drenched beachfront. Bright and energetic Aethers thrive here.',      1,  'map_soleil',   TRUE,  FALSE, FALSE, 'beach_day'),
    ('NEON_UNDERCITY',   'Neon Undercity',   'Glowing underground markets. Rave-type Aethers pulse with energy.',       5,  'map_neon',     FALSE, FALSE, FALSE, 'underground_rave'),
    ('BLOOM_GARDENS',    'Bloom Gardens',    'Lush botanical preserve. Nature and Bloom-type Aethers flourish.',        5,  'map_bloom',    FALSE, FALSE, FALSE, 'garden_ambient'),
    ('GRIM_QUARTERS',    'Grim Quarters',    'A shadowy district at the city edge. Grim-types lurk in alleyways.',     10, 'map_grim',     FALSE, FALSE, FALSE, 'dark_urban'),
    ('WILDE_OUTSKIRTS',  'Wilde Outskirts',  'Untamed wilderness beyond city limits. Unpredictable encounters.',       10, 'map_wilde',    FALSE, FALSE, FALSE, 'wild_nature'),
    ('AURA_SANCTUM',     'Aura Sanctum',     'A mystical spiritual district. Aura-types meditate in quiet plazas.',    15, 'map_aura',     FALSE, FALSE, FALSE, 'mystical_calm'),
    ('IRONCLAD_FOUNDRY', 'Ironclad Foundry', 'Industrial district of steel and fire. Ironclad-types dominate.',        15, 'map_iron',     FALSE, FALSE, FALSE, 'industrial'),
    ('VEX_LABYRINTH',    'Vex Labyrinth',    'A mind-bending maze district. Vex-types twist perception here.',         20, 'map_vex',      FALSE, FALSE, FALSE, 'distorted'),
    ('APEX_TOWER',       'Apex Tower',       'The pinnacle of the city. Legendary Aethers guard the summit.',          30, 'map_apex',     FALSE, TRUE,  TRUE,  'dramatic_peak');


-- =============================================================================
-- 5. factions
-- Rank names included per DATABASE.md (rank_0_name through rank_4_name).
-- Depends on: zones
-- =============================================================================
CREATE TABLE factions (
    id              SERIAL          PRIMARY KEY,
    faction_code    VARCHAR(30)     NOT NULL UNIQUE,
    display_name    VARCHAR(100)    NOT NULL,
    description     TEXT,
    home_zone_id    INTEGER         NOT NULL REFERENCES zones(id),
    rank_0_name     VARCHAR(50)     NOT NULL DEFAULT 'Outsider',
    rank_1_name     VARCHAR(50)     NOT NULL DEFAULT 'Initiate',
    rank_2_name     VARCHAR(50)     NOT NULL DEFAULT 'Member',
    rank_3_name     VARCHAR(50)     NOT NULL DEFAULT 'Veteran',
    rank_4_name     VARCHAR(50)     NOT NULL DEFAULT 'Elite',
    emblem_url      VARCHAR(255),
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

INSERT INTO factions
    (faction_code, display_name, description, home_zone_id, rank_0_name, rank_1_name, rank_2_name, rank_3_name, rank_4_name)
VALUES
    ('THE_VELVET_SYNDICATE', 'The Velvet Syndicate', 'Style is power. Collect the rarest fashion-types.',       1, 'Outsider', 'Prospect',   'Associate',  'Enforcer',   'Syndicate Lord'),
    ('SOLEIL_COLLECTIVE',    'Soleil Collective',    'Chase the light. Masters of Soleil-type Aethers.',        2, 'Outsider', 'Sun-Chaser', 'Illumined',  'Radiant',    'Dawnkeeper'),
    ('NEON_CIRCUIT',         'Neon Circuit',         'The underground rules. Rave-type specialists.',           3, 'Outsider', 'Static',     'Conductor',  'Amplifier',  'Circuit Master'),
    ('BLOOM_ORDER',          'Bloom Order',          'Guardians of nature. Bloom-type cultivators.',            4, 'Outsider', 'Seedling',   'Cultivator', 'Gardener',   'High Bloom'),
    ('GRIM_BROTHERHOOD',     'Grim Brotherhood',     'Embrace the dark. Grim-type hunters.',                   5, 'Outsider', 'Shadow',     'Acolyte',    'Reaper',     'Grand Grim'),
    ('WILDE_WANDERERS',      'Wilde Wanderers',      'No rules, no limits. Wilde-type trackers.',              6, 'Outsider', 'Stray',      'Feral',      'Wildborn',   'Untamed'),
    ('AURA_COUNCIL',         'Aura Council',         'Seekers of balance. Aura-type scholars.',                7, 'Outsider', 'Apprentice', 'Attuned',    'Channeler',  'Archmind'),
    ('IRONCLAD_UNION',       'Ironclad Union',       'Strength through industry. Ironclad-type engineers.',    8, 'Outsider', 'Laborer',    'Forger',     'Ironsmith',  'Union Warden'),
    ('VEX_COLLECTIVE',       'Vex Collective',       'Reality is a construct. Vex-type illusionists.',         9, 'Outsider', 'Trickster',  'Illusionist','Mindbreaker','Grand Vex'),
    ('APEX_ORDER',           'Apex Order',           'The elite few. Multi-type masters at the summit.',      10, 'Outsider', 'Aspirant',   'Contender',  'Champion',   'Apex Master');


-- =============================================================================
-- 6. weather_definitions
-- Shape per DATABASE.md: battle_type_id / battle_buff_pct / spawn_type_id / spawn_boost_pct
-- (Split FK pattern — separate type reference for battle vs spawn boost.)
-- Depends on: type_definitions
-- =============================================================================
CREATE TABLE weather_definitions (
    id                  SERIAL          PRIMARY KEY,
    weather_code        VARCHAR(30)     NOT NULL UNIQUE,
    display_name        VARCHAR(50)     NOT NULL,
    description         TEXT,
    battle_type_id      INTEGER         REFERENCES type_definitions(type_id),
    battle_buff_pct     NUMERIC(5,2)    NOT NULL DEFAULT 0.00,
    spawn_type_id       INTEGER         REFERENCES type_definitions(type_id),
    spawn_boost_pct     NUMERIC(5,2)    NOT NULL DEFAULT 0.00,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT now()
);

INSERT INTO weather_definitions
    (weather_code, display_name, description, battle_type_id, battle_buff_pct, spawn_type_id, spawn_boost_pct)
VALUES
    ('CLEAR',      'Clear',      'Standard conditions. No modifiers.',                    NULL, 0.00,  NULL,  0.00),
    ('SUNNY',      'Sunny',      'Bright sun. Boosts Soleil in battle and spawns.',          2, 50.00,    2, 30.00),
    ('OVERCAST',   'Overcast',   'Heavy clouds. Boosts Noir in battle and spawns.',           1, 50.00,    1, 30.00),
    ('NEON_STORM', 'Neon Storm', 'Electric atmosphere. Rave surges.',                         4, 30.00,    4, 50.00),
    ('BLOOM_RAIN', 'Bloom Rain', 'Gentle rain. Bloom thrives.',                               5, 30.00,    5, 40.00),
    ('GRIM_FOG',   'Grim Fog',   'Dense fog. Grim rises, others suppress.',                   6, 50.00,    6, 60.00),
    ('LUXE_GALA',  'Luxe Gala',  'Special event atmosphere. Luxe everywhere.',                3, 50.00,    3, 60.00),
    ('AURA_TIDE',  'Aura Tide',  'Mystical energy flows. Aura surges.',                       8, 50.00,    8, 40.00),
    ('IRON_HEAT',  'Iron Heat',  'Scorching industrial smog. Ironclad thrives.',              9, 30.00,    9, 40.00),
    ('VEX_WARP',   'Vex Warp',   'Reality distorts. Vex-types everywhere.',                  10, 50.00,   10, 60.00);


-- =============================================================================
-- 7. item_definitions
-- Depends on: rarity_tiers
-- =============================================================================
CREATE TABLE item_definitions (
    id                  SERIAL          PRIMARY KEY,
    item_code           VARCHAR(40)     NOT NULL UNIQUE,
    display_name        VARCHAR(100)    NOT NULL,
    description         TEXT,
    category            VARCHAR(30)     NOT NULL
                            CHECK (category IN ('CONSUMABLE', 'HELD', 'KEY', 'CAPTURE', 'EVOLUTION', 'COSMETIC')),
    rarity_tier_id      INTEGER         NOT NULL REFERENCES rarity_tiers(rarity_id),
    is_usable_in_battle BOOLEAN         NOT NULL DEFAULT FALSE,
    is_tradeable        BOOLEAN         NOT NULL DEFAULT TRUE,
    sell_price          INTEGER         NOT NULL DEFAULT 0 CHECK (sell_price >= 0),
    buy_price           INTEGER         NOT NULL DEFAULT 0 CHECK (buy_price >= 0),
    effect_payload      JSONB,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT now()
);

INSERT INTO item_definitions
    (item_code, display_name, description, category, rarity_tier_id, is_usable_in_battle, is_tradeable, sell_price, buy_price, effect_payload)
VALUES
    ('BIND_THREAD',    'Bind Thread',    'A basic capture tool. Standard catch rate.',           'CAPTURE',   1, FALSE, TRUE,   50,  200, '{"capture_rate_multiplier": 1.0}'),
    ('SILK_BIND',      'Silk Bind',      'Smoother and sturdier. Better catch rate.',            'CAPTURE',   2, FALSE, TRUE,  100,  400, '{"capture_rate_multiplier": 1.5}'),
    ('LUXE_LURE',      'Luxe Lure',      'Attracts Luxe-type Aethers. High catch rate.',         'CAPTURE',   3, FALSE, TRUE,  200,  800, '{"capture_rate_multiplier": 2.0, "type_affinity": "T03"}'),
    ('MASTER_WEAVE',   'Master Weave',   'Legendary capture tool. Near-certain catch.',          'CAPTURE',   6, FALSE, FALSE, 999, 9999, '{"capture_rate_multiplier": 255.0}'),
    ('STITCH_BALM',    'Stitch Balm',    'Restores 20 HP.',                                     'CONSUMABLE', 1, TRUE,  TRUE,   20,   80, '{"heal_flat": 20}'),
    ('PLUSH_POTION',   'Plush Potion',   'Restores 50 HP.',                                     'CONSUMABLE', 2, TRUE,  TRUE,   50,  200, '{"heal_flat": 50}'),
    ('GRAND_ELIXIR',   'Grand Elixir',   'Fully restores HP.',                                  'CONSUMABLE', 3, TRUE,  TRUE,  200,  800, '{"heal_pct": 100}'),
    ('CLARITY_MIST',   'Clarity Mist',   'Cures any non-volatile status condition.',            'CONSUMABLE', 2, TRUE,  TRUE,   80,  300, '{"cure_status": "ALL_NON_VOLATILE"}'),
    ('FOCUS_CRYSTAL',  'Focus Crystal',  'Grants 1 stack of Focus Boost.',                      'CONSUMABLE', 3, TRUE,  TRUE,  150,  600, '{"apply_status": "FOCUS_BOOST", "stacks": 1}'),
    ('FOCUS_LENS',     'Focus Lens',     'Held. Converts 10% of session XP to stat bonus.',     'HELD',       3, FALSE, TRUE,  300, 1200, '{"session_xp_to_stat_pct": 10}'),
    ('AETHER_CHARM',   'Aether Charm',   'Held. +10% EXP gain from focus sessions.',            'HELD',       2, FALSE, TRUE,  200,  800, '{"exp_bonus_pct": 10}'),
    ('IRON_CASING',    'Iron Casing',    'Held. +15% Guard.',                                   'HELD',       2, FALSE, TRUE,  200,  800, '{"stat_boost": {"guard_pct": 15}}'),
    ('BLOOM_STONE',    'Bloom Stone',    'Triggers evolution for Bloom-type Aethers.',          'EVOLUTION',  3, FALSE, TRUE,  500, 2000, '{"evolve_type_affinity": "T05"}'),
    ('GRIM_SHARD',     'Grim Shard',     'Triggers evolution for Grim-type Aethers.',           'EVOLUTION',  3, FALSE, TRUE,  500, 2000, '{"evolve_type_affinity": "T06"}'),
    ('AURA_PRISM',     'Aura Prism',     'Triggers evolution for Aura-type Aethers.',           'EVOLUTION',  4, FALSE, TRUE,  800, 3200, '{"evolve_type_affinity": "T08"}'),
    ('BINDER_JOURNAL', 'Binder Journal', 'Your journal. Tracks all collected Aethers.',         'KEY',        1, FALSE, FALSE,   0,    0, NULL),
    ('ZONE_PASS',      'Zone Pass',      'Grants access to a locked zone.',                     'KEY',        2, FALSE, FALSE,   0,    0, '{"unlocks_zone": true}');


-- =============================================================================
-- 8. aether_species
-- Stat naming: vigor=HP, strike=Atk, guard=Def, aether_atk=SpAtk, ward=SpDef, drift=Spd
-- Added: evolution_stage, evolves_to_id, evolution_trigger, evolution_trigger_value,
--        is_legendary, is_god_tier, is_breedable, base_stat_total (generated)
-- Depends on: rarity_tiers, type_definitions, item_definitions (self-ref)
-- =============================================================================
CREATE TABLE aether_species (
    id                      SERIAL          PRIMARY KEY,
    species_code            VARCHAR(40)     NOT NULL UNIQUE,
    display_name            VARCHAR(100)    NOT NULL,
    dex_number              SMALLINT        NOT NULL UNIQUE,
    description             TEXT,

    primary_type_id         INTEGER         NOT NULL REFERENCES type_definitions(type_id),
    secondary_type_id       INTEGER         REFERENCES type_definitions(type_id),
    rarity_tier_id          INTEGER         NOT NULL REFERENCES rarity_tiers(rarity_id),

    evolution_stage         SMALLINT        NOT NULL DEFAULT 1 CHECK (evolution_stage BETWEEN 1 AND 3),
    evolves_from_id         INTEGER         REFERENCES aether_species(id),
    evolves_to_id           INTEGER         REFERENCES aether_species(id),
    evolution_trigger       VARCHAR(30)     CHECK (evolution_trigger IN ('LEVEL_UP', 'ITEM', 'FOCUS_SESSIONS', 'FRIENDSHIP')),
    evolution_trigger_value VARCHAR(50),

    -- Stats (Aetheria naming convention)
    base_vigor              SMALLINT        NOT NULL CHECK (base_vigor > 0),
    base_strike             SMALLINT        NOT NULL CHECK (base_strike > 0),
    base_guard              SMALLINT        NOT NULL CHECK (base_guard > 0),
    base_aether_atk         SMALLINT        NOT NULL CHECK (base_aether_atk > 0),
    base_ward               SMALLINT        NOT NULL CHECK (base_ward > 0),
    base_drift              SMALLINT        NOT NULL CHECK (base_drift > 0),
    base_stat_total         SMALLINT        GENERATED ALWAYS AS
                                (base_vigor + base_strike + base_guard + base_aether_atk + base_ward + base_drift)
                                STORED,

    is_legendary            BOOLEAN         NOT NULL DEFAULT FALSE,
    is_god_tier             BOOLEAN         NOT NULL DEFAULT FALSE,
    is_breedable            BOOLEAN         NOT NULL DEFAULT TRUE,

    base_capture_rate       SMALLINT        NOT NULL DEFAULT 45 CHECK (base_capture_rate BETWEEN 1 AND 255),
    base_focus_exp_yield    SMALLINT        NOT NULL DEFAULT 50,
    base_friendship         SMALLINT        NOT NULL DEFAULT 70,

    sprite_url              VARCHAR(255),
    shiny_sprite_url        VARCHAR(255),
    is_obtainable           BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- Insert all species with evolves_to_id = NULL first (second pass wires the chain)
-- BST targets: Stage 1 ≈ 255–265, Stage 2 ≈ 385–420, Stage 3 ≈ 510–535
INSERT INTO aether_species
    (species_code, display_name, dex_number, description,
     primary_type_id, secondary_type_id, rarity_tier_id,
     evolution_stage, evolution_trigger, evolution_trigger_value,
     base_vigor, base_strike, base_guard, base_aether_atk, base_ward, base_drift,
     is_legendary, is_god_tier, is_breedable,
     base_capture_rate, base_focus_exp_yield, base_friendship)
VALUES
    -- Noctelle line (Noir, type 1)
    ('NOCTELLE',   'Noctelle',    1, 'A sleek Noir-type starter draped in midnight fabric.',     1, NULL, 1, 1, 'LEVEL_UP', '16',  45, 49, 49, 65, 65, 45, FALSE, FALSE, TRUE,  45, 60, 70),
    ('NOCTARA',    'Noctara',     2, 'Noctelle evolved. Sharper edges, deeper shadows.',          1, NULL, 2, 2, 'LEVEL_UP', '36',  65, 72, 62, 85, 73, 65, FALSE, FALSE, TRUE,  45, 80, 70),
    ('NOCTERION',  'Nocterion',   3, 'The apex Noir predator. A walking void.',                  1,  6,   3, 3, NULL,        NULL,  80, 95, 75,110, 85, 90, FALSE, FALSE, TRUE,  45,110, 70),
    -- Solara line (Soleil, type 2)
    ('SOLARA',     'Solara',      4, 'A radiant Soleil-type starter that glows at dawn.',        2, NULL, 1, 1, 'LEVEL_UP', '16',  45, 65, 45, 49, 49, 45, FALSE, FALSE, TRUE,  45, 60, 70),
    ('SOLARIUS',   'Solarius',    5, 'Solara evolved. A blazing silhouette of pure light.',      2, NULL, 2, 2, 'LEVEL_UP', '36',  65, 85, 55, 65, 55, 72, FALSE, FALSE, TRUE,  45, 80, 70),
    ('SOLARIUS_X', 'Solarius X',  6, 'Solar pinnacle. Radiates heat that warps space.',          2,  8,   3, 3, NULL,        NULL,  80,110, 65, 95, 70,100, FALSE, FALSE, TRUE,  45,110, 70),
    -- Luxkin line (Luxe, type 3)
    ('LUXKIN',     'Luxkin',      7, 'A refined Luxe-type starter born into high fashion.',      3, NULL, 1, 1, 'LEVEL_UP', '16',  45, 49, 45, 65, 49, 45, FALSE, FALSE, TRUE,  45, 60, 70),
    ('LUXARA',     'Luxara',      8, 'Luxkin evolved. Adorned in rare materials.',               3, NULL, 2, 2, 'LEVEL_UP', '36',  65, 60, 58, 88, 65, 55, FALSE, FALSE, TRUE,  45, 80, 70),
    ('GRANDLUXE',  'Grandluxe',   9, 'Fashion made divine. Commands respect on sight.',          3,  7,   3, 3, NULL,        NULL,  80, 80, 80,115, 90, 70, FALSE, FALSE, TRUE,  45,110, 70),
    -- Common wilds
    ('RAVLET',     'Ravlet',     10, 'A tiny Rave-type that hums with neon energy.',             4, NULL, 1, 1, NULL,        NULL,  40, 55, 35, 50, 35, 62, FALSE, FALSE, TRUE, 190, 50, 70),
    ('BLOOMLET',   'Bloomlet',   11, 'A small Bloom-type that sprouts flowers when happy.',      5, NULL, 1, 1, NULL,        NULL,  50, 45, 50, 45, 55, 35, FALSE, FALSE, TRUE, 190, 50, 70),
    ('GRIMKIN',    'Grimkin',    12, 'A mischievous Grim-type hiding in alley shadows.',         6, NULL, 1, 1, NULL,        NULL,  45, 55, 40, 35, 45, 60, FALSE, FALSE, TRUE, 190, 50, 70),
    ('WILDPUP',    'Wildpup',    13, 'A scrappy Wilde-type puppy from the outskirts.',           7, NULL, 1, 1, NULL,        NULL,  50, 65, 40, 35, 35, 65, FALSE, FALSE, TRUE, 190, 50, 70),
    -- Rare wilds
    ('AURATH',     'Aurath',     14, 'An ethereal Aura-type that floats silently.',              8, NULL, 2, 1, NULL,        NULL,  60, 50, 55, 85, 80, 65, FALSE, FALSE, TRUE,  75, 80, 70),
    ('IRONHIDE',   'Ironhide',   15, 'A sturdy Ironclad-type built from city scrap.',            9, NULL, 2, 1, NULL,        NULL,  80, 90, 90, 40, 60, 30, FALSE, FALSE, TRUE,  75, 80, 70),
    ('VEXLING',    'Vexling',    16, 'A disorienting Vex-type that bends light around it.',     10, NULL, 2, 1, NULL,        NULL,  55, 60, 45, 90, 75, 85, FALSE, FALSE, TRUE,  75, 80, 70);

-- Second pass: wire evolves_from_id and evolves_to_id
UPDATE aether_species SET
    evolves_to_id = (SELECT id FROM aether_species WHERE species_code = 'NOCTARA')
    WHERE species_code = 'NOCTELLE';
UPDATE aether_species SET
    evolves_from_id = (SELECT id FROM aether_species WHERE species_code = 'NOCTELLE'),
    evolves_to_id   = (SELECT id FROM aether_species WHERE species_code = 'NOCTERION')
    WHERE species_code = 'NOCTARA';
UPDATE aether_species SET
    evolves_from_id = (SELECT id FROM aether_species WHERE species_code = 'NOCTARA')
    WHERE species_code = 'NOCTERION';

UPDATE aether_species SET
    evolves_to_id = (SELECT id FROM aether_species WHERE species_code = 'SOLARIUS')
    WHERE species_code = 'SOLARA';
UPDATE aether_species SET
    evolves_from_id = (SELECT id FROM aether_species WHERE species_code = 'SOLARA'),
    evolves_to_id   = (SELECT id FROM aether_species WHERE species_code = 'SOLARIUS_X')
    WHERE species_code = 'SOLARIUS';
UPDATE aether_species SET
    evolves_from_id = (SELECT id FROM aether_species WHERE species_code = 'SOLARIUS')
    WHERE species_code = 'SOLARIUS_X';

UPDATE aether_species SET
    evolves_to_id = (SELECT id FROM aether_species WHERE species_code = 'LUXARA')
    WHERE species_code = 'LUXKIN';
UPDATE aether_species SET
    evolves_from_id = (SELECT id FROM aether_species WHERE species_code = 'LUXKIN'),
    evolves_to_id   = (SELECT id FROM aether_species WHERE species_code = 'GRANDLUXE')
    WHERE species_code = 'LUXARA';
UPDATE aether_species SET
    evolves_from_id = (SELECT id FROM aether_species WHERE species_code = 'LUXARA')
    WHERE species_code = 'GRANDLUXE';


-- =============================================================================
-- 9. moves
-- stamina_cost replaces pp to match DATABASE.md.
-- Depends on: type_definitions
-- =============================================================================
CREATE TABLE moves (
    id              SERIAL          PRIMARY KEY,
    move_code       VARCHAR(40)     NOT NULL UNIQUE,
    display_name    VARCHAR(100)    NOT NULL,
    description     TEXT,
    type_id         INTEGER         NOT NULL REFERENCES type_definitions(type_id),
    category        VARCHAR(10)     NOT NULL CHECK (category IN ('PHYSICAL', 'SPECIAL', 'STATUS')),
    power           SMALLINT        CHECK (power IS NULL OR power > 0),
    accuracy        SMALLINT        CHECK (accuracy IS NULL OR accuracy BETWEEN 1 AND 100),
    stamina_cost    SMALLINT        NOT NULL DEFAULT 10 CHECK (stamina_cost > 0),
    priority        SMALLINT        NOT NULL DEFAULT 0,
    is_contact      BOOLEAN         NOT NULL DEFAULT FALSE,
    effect_payload  JSONB,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

INSERT INTO moves
    (move_code, display_name, description, type_id, category, power, accuracy, stamina_cost, priority, is_contact, effect_payload)
VALUES
    -- Noir (1)
    ('SHADOW_SLASH',   'Shadow Slash',   'A swift slash of dark fabric.',                         1, 'PHYSICAL',  65,  95, 20, 0, TRUE,  NULL),
    ('MIDNIGHT_VEIL',  'Midnight Veil',  'Wraps foe in darkness. May cause Confusion.',           1, 'SPECIAL',   80,  90, 10, 0, FALSE, '{"apply_status": "CONFUSED", "chance_pct": 30}'),
    ('VOID_SHROUD',    'Void Shroud',    'Raises user Ward by 1 stage.',                         1, 'STATUS',   NULL, NULL,20, 0, FALSE, '{"stat_change": {"ward": 1}, "target": "self"}'),
    -- Soleil (2)
    ('SOLAR_FLARE',    'Solar Flare',    'A burst of radiant energy.',                            2, 'SPECIAL',   90,  95, 10, 0, FALSE, NULL),
    ('DAWN_STRIKE',    'Dawn Strike',    'Quick sunrise slash. High priority.',                   2, 'PHYSICAL',  40, 100, 30, 1, TRUE,  NULL),
    ('BRILLIANCE',     'Brilliance',     'Raises user Aether Atk by 2 stages.',                  2, 'STATUS',   NULL, NULL,10, 0, FALSE, '{"stat_change": {"aether_atk": 2}, "target": "self"}'),
    -- Luxe (3)
    ('PRESTIGE_PULSE', 'Prestige Pulse', 'An elegant energy wave.',                               3, 'SPECIAL',   75, 100, 15, 0, FALSE, NULL),
    ('COUTURE_CLAW',   'Couture Claw',   'A stylish slashing attack.',                            3, 'PHYSICAL',  70,  95, 15, 0, TRUE,  NULL),
    ('RUNWAY_GLARE',   'Runway Glare',   'Lowers foe Drift with an icy stare.',                  3, 'STATUS',   NULL, 100, 20, 0, FALSE, '{"stat_change": {"drift": -1}, "target": "foe"}'),
    -- Rave (4)
    ('NEON_BLAST',     'Neon Blast',     'Crackling electric burst. May Paralyse.',               4, 'SPECIAL',   95,  90, 15, 0, FALSE, '{"apply_status": "PARALYSIS", "chance_pct": 10}'),
    ('BASS_DROP',      'Bass Drop',      'A sonic slam. May cause Flinch.',                       4, 'PHYSICAL',  80,  90, 10, 0, FALSE, '{"apply_status": "FLINCH", "chance_pct": 30}'),
    ('STROBE_HAZE',    'Strobe Haze',    'Disorienting lights. Lowers foe accuracy.',             4, 'STATUS',   NULL, 100, 15, 0, FALSE, '{"stat_change": {"accuracy": -1}, "target": "foe"}'),
    -- Bloom (5)
    ('PETAL_STORM',    'Petal Storm',    'A whirlwind of sharp petals.',                          5, 'SPECIAL',   80, 100, 10, 0, FALSE, NULL),
    ('VINE_WRAP',      'Vine Wrap',      'Traps foe in vines. Applies Bound.',                    5, 'PHYSICAL',  35, 100, 15, 0, TRUE,  '{"apply_status": "BOUND", "chance_pct": 100}'),
    ('BLOOM_RESTORE',  'Bloom Restore',  'Restores user HP by 50%.',                             5, 'STATUS',   NULL, NULL,10, 0, FALSE, '{"heal_pct": 50, "target": "self"}'),
    -- Grim (6)
    ('GRIM_REAP',      'Grim Reap',      'A haunting strike. May Curse the foe.',                 6, 'PHYSICAL',  80,  90, 10, 0, TRUE,  '{"apply_status": "CURSED", "chance_pct": 20}'),
    ('SHADOW_MIST',    'Shadow Mist',    'Poisons the foe in thick miasma.',                      6, 'SPECIAL',   65,  90, 15, 0, FALSE, '{"apply_status": "POISON", "chance_pct": 40}'),
    ('CURSED_SEAL',    'Cursed Seal',    'Applies Bad Poison to the foe.',                       6, 'STATUS',   NULL,  90, 10, 0, FALSE, '{"apply_status": "BAD_POISON", "chance_pct": 100}'),
    -- Wilde (7)
    ('FERAL_RUSH',     'Feral Rush',     'An untamed physical assault.',                          7, 'PHYSICAL', 100,  95, 10, 0, TRUE,  NULL),
    ('WILD_HOWL',      'Wild Howl',      'Lowers foe Strike by 2 stages.',                       7, 'STATUS',   NULL, 100, 15, 0, FALSE, '{"stat_change": {"strike": -2}, "target": "foe"}'),
    ('OUTBURST',       'Outburst',       'Deals 150 power. User confused afterwards.',            7, 'PHYSICAL', 150, 100,  5, 0, TRUE,  '{"apply_status": "CONFUSED", "chance_pct": 100, "target": "self"}'),
    -- Aura (8)
    ('AURA_SPHERE',    'Aura Sphere',    'A pure energy sphere. Never misses.',                   8, 'SPECIAL',   80, NULL,20, 0, FALSE, NULL),
    ('SERENITY_FIELD', 'Serenity Field', 'Sets Reflect and Light Screen for 5 turns.',            8, 'STATUS',   NULL, NULL, 5, 0, FALSE, '{"apply_field": ["REFLECT", "LIGHT_SCREEN"]}'),
    ('CLARITY_PULSE',  'Clarity Pulse',  'Heals foe status. Odd but strategic.',                  8, 'STATUS',   NULL, NULL,10, 0, FALSE, '{"cure_status": "ALL_NON_VOLATILE", "target": "foe"}'),
    -- Ironclad (9)
    ('STEEL_PRESS',    'Steel Press',    'A crushing metallic body slam.',                         9, 'PHYSICAL',  85,  90, 10, 0, TRUE,  NULL),
    ('FORGE_BLAST',    'Forge Blast',    'Superheated metal projectile. May Burn.',                9, 'SPECIAL',   80,  85, 10, 0, FALSE, '{"apply_status": "BURN", "chance_pct": 25}'),
    ('IRON_DEFENSE',   'Iron Defense',   'Raises user Guard by 2 stages.',                        9, 'STATUS',   NULL, NULL,15, 0, FALSE, '{"stat_change": {"guard": 2}, "target": "self"}'),
    -- Vex (10)
    ('MIND_TWIST',     'Mind Twist',     'A psychic assault that confuses.',                      10, 'SPECIAL',   75, 100, 15, 0, FALSE, '{"apply_status": "CONFUSED", "chance_pct": 20}'),
    ('TRICK_SHIFT',    'Trick Shift',    'Swaps user and foe stat stage changes.',               10, 'STATUS',   NULL, NULL,10, 0, FALSE, '{"swap_stat_changes": true}'),
    ('VEX_PULSE',      'Vex Pulse',      'Chaotic energy. Power varies 50–150.',                 10, 'SPECIAL',  NULL,  90, 15, 0, FALSE, '{"random_power": {"min": 50, "max": 150}}');


-- =============================================================================
-- 10. species_learnable_moves
-- learn_value (varchar) per DATABASE.md — flexible for level, TM code, etc.
-- Depends on: aether_species, moves
-- =============================================================================
CREATE TABLE species_learnable_moves (
    id              SERIAL          PRIMARY KEY,
    species_id      INTEGER         NOT NULL REFERENCES aether_species(id),
    move_id         INTEGER         NOT NULL REFERENCES moves(id),
    learn_method    VARCHAR(20)     NOT NULL CHECK (learn_method IN ('LEVEL_UP', 'TM', 'EGG', 'TUTOR')),
    learn_value     VARCHAR(10),    -- level as string for LEVEL_UP, TM code for TM
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    UNIQUE (species_id, move_id, learn_method)
);

INSERT INTO species_learnable_moves (species_id, move_id, learn_method, learn_value)
SELECT s.id, m.id, 'LEVEL_UP', lv.lv
FROM (VALUES
    -- Noctelle line
    ('NOCTELLE',  'SHADOW_SLASH',   '1'), ('NOCTELLE',  'VOID_SHROUD',   '10'), ('NOCTELLE',  'MIDNIGHT_VEIL', '18'),
    ('NOCTARA',   'SHADOW_SLASH',   '1'), ('NOCTARA',   'VOID_SHROUD',    '1'), ('NOCTARA',   'MIDNIGHT_VEIL', '20'),
    ('NOCTERION', 'SHADOW_SLASH',   '1'), ('NOCTERION', 'VOID_SHROUD',    '1'), ('NOCTERION', 'MIDNIGHT_VEIL',  '1'),
    -- Solara line
    ('SOLARA',     'DAWN_STRIKE',  '1'), ('SOLARA',     'BRILLIANCE',  '10'), ('SOLARA',     'SOLAR_FLARE', '18'),
    ('SOLARIUS',   'DAWN_STRIKE',  '1'), ('SOLARIUS',   'BRILLIANCE',   '1'), ('SOLARIUS',   'SOLAR_FLARE', '20'),
    ('SOLARIUS_X', 'DAWN_STRIKE',  '1'), ('SOLARIUS_X', 'BRILLIANCE',   '1'), ('SOLARIUS_X', 'SOLAR_FLARE',  '1'),
    -- Luxkin line
    ('LUXKIN',    'RUNWAY_GLARE',  '1'), ('LUXKIN',    'COUTURE_CLAW', '10'), ('LUXKIN',    'PRESTIGE_PULSE','18'),
    ('LUXARA',    'RUNWAY_GLARE',  '1'), ('LUXARA',    'COUTURE_CLAW',  '1'), ('LUXARA',    'PRESTIGE_PULSE','20'),
    ('GRANDLUXE', 'RUNWAY_GLARE',  '1'), ('GRANDLUXE', 'COUTURE_CLAW',  '1'), ('GRANDLUXE', 'PRESTIGE_PULSE', '1'),
    -- Wild Aethers
    ('RAVLET',   'NEON_BLAST',    '1'), ('RAVLET',   'BASS_DROP',     '12'),
    ('BLOOMLET', 'PETAL_STORM',   '1'), ('BLOOMLET', 'VINE_WRAP',     '12'),
    ('GRIMKIN',  'SHADOW_MIST',   '1'), ('GRIMKIN',  'GRIM_REAP',     '14'),
    ('WILDPUP',  'FERAL_RUSH',    '1'), ('WILDPUP',  'WILD_HOWL',     '10'),
    ('AURATH',   'AURA_SPHERE',   '1'), ('AURATH',   'SERENITY_FIELD','18'),
    ('IRONHIDE', 'STEEL_PRESS',   '1'), ('IRONHIDE', 'IRON_DEFENSE',  '12'),
    ('VEXLING',  'MIND_TWIST',    '1'), ('VEXLING',  'VEX_PULSE',     '16')
) AS lv(sc, mc, lv)
JOIN aether_species s ON s.species_code = lv.sc
JOIN moves m ON m.move_code = lv.mc;


-- =============================================================================
-- 11. zone_spawn_rules
-- Added: time_condition, weather_condition per DATABASE.md
-- Depends on: zones, aether_species
-- =============================================================================
CREATE TABLE zone_spawn_rules (
    id                  SERIAL          PRIMARY KEY,
    zone_id             INTEGER         NOT NULL REFERENCES zones(id),
    species_id          INTEGER         NOT NULL REFERENCES aether_species(id),
    spawn_weight        SMALLINT        NOT NULL DEFAULT 10 CHECK (spawn_weight > 0),
    time_condition      VARCHAR(20)     DEFAULT 'ANY' CHECK (time_condition IN ('ANY', 'DAY', 'NIGHT', 'DAWN', 'DUSK')),
    weather_condition   VARCHAR(30),    -- weather_code FK (soft ref); NULL = any weather
    min_player_level    SMALLINT        NOT NULL DEFAULT 1,
    is_rare_encounter   BOOLEAN         NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT now(),
    UNIQUE (zone_id, species_id, time_condition, weather_condition)
);

INSERT INTO zone_spawn_rules (zone_id, species_id, spawn_weight, time_condition, weather_condition, min_player_level, is_rare_encounter)
SELECT z.id, s.id, sr.w, sr.tc, sr.wc, sr.ml, sr.ir
FROM (VALUES
    ('VELVET_DISTRICT',  'NOCTELLE',   40, 'ANY',   NULL,         1,  FALSE),
    ('VELVET_DISTRICT',  'GRIMKIN',    30, 'NIGHT', NULL,         1,  FALSE),
    ('VELVET_DISTRICT',  'NOCTARA',     5, 'NIGHT', 'OVERCAST',   5,  TRUE),
    ('SOLEIL_COAST',     'SOLARA',     40, 'ANY',   NULL,         1,  FALSE),
    ('SOLEIL_COAST',     'BLOOMLET',   35, 'DAY',   NULL,         1,  FALSE),
    ('SOLEIL_COAST',     'SOLARIUS',    5, 'DAWN',  'SUNNY',      5,  TRUE),
    ('NEON_UNDERCITY',   'RAVLET',     50, 'NIGHT', NULL,         5,  FALSE),
    ('NEON_UNDERCITY',   'VEXLING',    15, 'ANY',   NULL,         8,  FALSE),
    ('BLOOM_GARDENS',    'BLOOMLET',   50, 'DAY',   NULL,         5,  FALSE),
    ('BLOOM_GARDENS',    'AURATH',     10, 'DAWN',  'BLOOM_RAIN', 8,  TRUE),
    ('GRIM_QUARTERS',    'GRIMKIN',    50, 'NIGHT', NULL,        10,  FALSE),
    ('GRIM_QUARTERS',    'NOCTARA',    10, 'NIGHT', 'GRIM_FOG',  10,  TRUE),
    ('WILDE_OUTSKIRTS',  'WILDPUP',    50, 'ANY',   NULL,        10,  FALSE),
    ('WILDE_OUTSKIRTS',  'RAVLET',     20, 'ANY',   NULL,        10,  FALSE),
    ('AURA_SANCTUM',     'AURATH',     30, 'DAWN',  NULL,        15,  FALSE),
    ('AURA_SANCTUM',     'BLOOMLET',   20, 'DAY',   NULL,        15,  FALSE),
    ('IRONCLAD_FOUNDRY', 'IRONHIDE',   40, 'ANY',   NULL,        15,  FALSE),
    ('IRONCLAD_FOUNDRY', 'WILDPUP',    20, 'ANY',   NULL,        15,  FALSE),
    ('VEX_LABYRINTH',    'VEXLING',    40, 'ANY',   NULL,        20,  FALSE),
    ('VEX_LABYRINTH',    'GRIMKIN',    15, 'NIGHT', NULL,        20,  FALSE),
    ('APEX_TOWER',       'NOCTERION',   2, 'NIGHT', 'OVERCAST',  30,  TRUE),
    ('APEX_TOWER',       'SOLARIUS_X',  2, 'DAWN',  'SUNNY',     30,  TRUE),
    ('APEX_TOWER',       'GRANDLUXE',   2, 'ANY',   'LUXE_GALA', 30,  TRUE)
) AS sr(zc, sc, w, tc, wc, ml, ir)
JOIN zones z ON z.zone_code = sr.zc
JOIN aether_species s ON s.species_code = sr.sc;


-- =============================================================================
-- 12. zone_type_affinities
-- affinity_strength (smallint 1–10) per DATABASE.md
-- Depends on: zones, type_definitions
-- =============================================================================
CREATE TABLE zone_type_affinities (
    id                  SERIAL          PRIMARY KEY,
    zone_id             INTEGER         NOT NULL REFERENCES zones(id),
    type_id             INTEGER         NOT NULL REFERENCES type_definitions(type_id),
    affinity_strength   SMALLINT        NOT NULL DEFAULT 5 CHECK (affinity_strength BETWEEN 1 AND 10),
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT now(),
    UNIQUE (zone_id, type_id)
);

-- 10 = home turf, 7 = strong affinity, 5 = moderate
INSERT INTO zone_type_affinities (zone_id, type_id, affinity_strength)
SELECT z.id, t.type_id, za.strength
FROM (VALUES
    ('VELVET_DISTRICT',  'T01', 10), ('VELVET_DISTRICT',  'T03',  7),
    ('SOLEIL_COAST',     'T02', 10), ('SOLEIL_COAST',     'T05',  7),
    ('NEON_UNDERCITY',   'T04', 10), ('NEON_UNDERCITY',   'T10',  7),
    ('BLOOM_GARDENS',    'T05', 10), ('BLOOM_GARDENS',    'T08',  7),
    ('GRIM_QUARTERS',    'T06', 10), ('GRIM_QUARTERS',    'T01',  7),
    ('WILDE_OUTSKIRTS',  'T07', 10),
    ('AURA_SANCTUM',     'T08', 10), ('AURA_SANCTUM',     'T05',  7),
    ('IRONCLAD_FOUNDRY', 'T09', 10),
    ('VEX_LABYRINTH',    'T10', 10), ('VEX_LABYRINTH',    'T06',  7),
    ('APEX_TOWER',       'T01',  5), ('APEX_TOWER',       'T02',  5), ('APEX_TOWER', 'T03', 5)
) AS za(zc, tc, strength)
JOIN zones z ON z.zone_code = za.zc
JOIN type_definitions t ON t.type_code = za.tc;


-- =============================================================================
-- 13. subject_type_mappings
-- subject_tag (not subject_code), xp_multiplier added per DATABASE.md
-- Depends on: type_definitions
-- =============================================================================
CREATE TABLE subject_type_mappings (
    id              SERIAL          PRIMARY KEY,
    subject_tag     VARCHAR(40)     NOT NULL UNIQUE,    -- matches focus_sessions.subject_tag
    display_name    VARCHAR(100)    NOT NULL,
    type_id         INTEGER         NOT NULL REFERENCES type_definitions(type_id),
    xp_multiplier   NUMERIC(4,2)    NOT NULL DEFAULT 1.00,
    description     TEXT,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

INSERT INTO subject_type_mappings (subject_tag, display_name, type_id, xp_multiplier, description)
VALUES
    ('MATHEMATICS',       'Mathematics',        9, 1.10, 'Logic and precision maps to Ironclad.'),
    ('SCIENCES',          'Sciences',           5, 1.10, 'Natural sciences tie to Bloom.'),
    ('LITERATURE',        'Literature',         1, 1.00, 'Dark prose and narrative map to Noir.'),
    ('HISTORY',           'History',            6, 1.00, 'The weight of the past maps to Grim.'),
    ('LANGUAGES',         'Languages',          3, 1.10, 'Eloquence and style maps to Luxe.'),
    ('ARTS',              'Arts',               7, 1.00, 'Wild creativity maps to Wilde.'),
    ('MUSIC',             'Music',              4, 1.00, 'Rhythm and energy maps to Rave.'),
    ('PHILOSOPHY',        'Philosophy',         8, 1.20, 'Deep thought maps to Aura.'),
    ('TECHNOLOGY',        'Technology',        10, 1.20, 'Disruptive innovation maps to Vex.'),
    ('SOCIAL_SCIENCES',   'Social Sciences',    2, 1.00, 'Human connection maps to Soleil.'),
    ('PHYSICAL_TRAINING', 'Physical Training',  9, 1.10, 'Discipline and endurance maps to Ironclad.'),
    ('MEDITATION',        'Meditation',         8, 1.30, 'Mindfulness maps to Aura. Highest XP multiplier.'),
    ('BUSINESS',          'Business',           3, 1.10, 'Commerce and style maps to Luxe.'),
    ('CODING',            'Coding',            10, 1.20, 'Logic-bending code maps to Vex.'),
    ('DESIGN',            'Design',             3, 1.10, 'Visual refinement maps to Luxe.');


-- =============================================================================
-- 14. breeding_compatibility
-- Shape per DATABASE.md: compatibility (varchar tier), requires_item (varchar)
-- Depends on: type_definitions
-- =============================================================================
CREATE TABLE breeding_compatibility (
    id              SERIAL          PRIMARY KEY,
    type_a_id       INTEGER         NOT NULL REFERENCES type_definitions(type_id),
    type_b_id       INTEGER         NOT NULL REFERENCES type_definitions(type_id),
    compatibility   VARCHAR(20)     NOT NULL DEFAULT 'AVERAGE'
                        CHECK (compatibility IN ('INCOMPATIBLE', 'LOW', 'AVERAGE', 'HIGH', 'PERFECT')),
    requires_item   VARCHAR(40),    -- item_code (soft ref, validated at app layer)
    egg_bonus_desc  TEXT,
    shiny_boost     NUMERIC(6,4)    NOT NULL DEFAULT 0.0000,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    UNIQUE (type_a_id, type_b_id)
);

-- Cross-type rows only. Lower type_id always in type_a_id column.
-- Same-type breeding is handled at app layer (always permitted, no row needed).
-- Unlisted cross-type pairs default to AVERAGE at app layer.
INSERT INTO breeding_compatibility (type_a_id, type_b_id, compatibility, requires_item, egg_bonus_desc, shiny_boost)
VALUES
    (1,  2, 'PERFECT', NULL, 'Noir x Soleil — light and dark. Highest shiny chance.',       0.0050),
    (1,  6, 'HIGH',    NULL, 'Noir x Grim — shadow synergy. May inherit dark moves.',        0.0025),
    (1,  9, 'AVERAGE', NULL, 'Ironclad x Noir — hard and sharp. Egg gets Guard bonus.',      0.0015),
    (2,  5, 'HIGH',    NULL, 'Soleil x Bloom — sun and nature. Egg gets bonus Vigor.',       0.0020),
    (2,  8, 'AVERAGE', NULL, 'Aura x Soleil — mind and light. Egg gets Aether Atk boost.',  0.0020),
    (3,  7, 'HIGH',    NULL, 'Luxe x Wilde — refined meets feral. Unpredictable offspring.', 0.0030),
    (4, 10, 'HIGH',    NULL, 'Rave x Vex — chaos energy. Egg may have random bonus stat.',   0.0040),
    (5,  8, 'PERFECT', NULL, 'Bloom x Aura — nature and spirit. High harmony. Bonus EXP.',  0.0050),
    (6, 10, 'AVERAGE', NULL, 'Grim x Vex — dark tricks. Egg may inherit status move.',       0.0025),
    (7,  9, 'HIGH',    NULL, 'Wilde x Ironclad — raw power. Egg gets Strike boost.',         0.0020),
    (1,  5, 'LOW',     NULL, 'Noir x Bloom — darkness suppresses growth.',                   0.0000),
    (2,  6, 'LOW',     NULL, 'Soleil x Grim — light and dark conflict.',                     0.0000),
    (3,  4, 'LOW',     NULL, 'Luxe x Rave — refined clashes with chaotic.',                  0.0000);

-- =============================================================================
-- END V002__phase1_static_config.sql
-- =============================================================================
