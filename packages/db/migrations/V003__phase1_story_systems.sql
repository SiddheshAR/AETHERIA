-- =============================================================================
-- V003__phase1_story_systems.sql
-- Phase 1: Story Systems
-- Aetheria — Never edit after apply. Create V004 for any changes.
-- =============================================================================

-- =============================================================================
-- 1. story_seasons
-- Narrative seasons that drive world events and zone unlocks.
-- Depends on: zones
-- =============================================================================
CREATE TABLE story_seasons (
    id              SERIAL          PRIMARY KEY,
    season_code     VARCHAR(30)     NOT NULL UNIQUE,
    title           VARCHAR(100)    NOT NULL,
    description     TEXT,
    starts_at       TIMESTAMPTZ     NOT NULL,
    ends_at         TIMESTAMPTZ     NOT NULL,
    is_active       BOOLEAN         NOT NULL DEFAULT FALSE,
    unlocks_zone_id INTEGER         REFERENCES zones(id),  -- zone revealed this season
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CHECK (ends_at > starts_at)
);

INSERT INTO story_seasons
    (season_code, title, description, starts_at, ends_at, is_active, unlocks_zone_id)
VALUES
    ('SEASON_1_VELVET_DAWN',
     'Velvet Dawn',
     'The city awakens. New Binders arrive in the Velvet District and Soleil Coast. The first Aethers stir.',
     '2025-01-01 00:00:00+00', '2025-04-01 00:00:00+00', FALSE,
     NULL),

    ('SEASON_2_NEON_UNDERGROUND',
     'Neon Underground',
     'The Neon Undercity opens its gates. Rave-types surge. The Bloom Gardens bloom for the first time.',
     '2025-04-01 00:00:00+00', '2025-07-01 00:00:00+00', FALSE,
     (SELECT id FROM zones WHERE zone_code = 'NEON_UNDERCITY')),

    ('SEASON_3_GRIM_TIDE',
     'Grim Tide',
     'Darkness spreads. Grim Quarters and Wilde Outskirts open. Strange fog rolls in nightly.',
     '2025-07-01 00:00:00+00', '2025-10-01 00:00:00+00', FALSE,
     (SELECT id FROM zones WHERE zone_code = 'GRIM_QUARTERS')),

    ('SEASON_4_APEX_ASCENT',
     'Apex Ascent',
     'The Aura Sanctum, Ironclad Foundry, Vex Labyrinth open. The Apex Tower looms. Legends emerge.',
     '2025-10-01 00:00:00+00', '2026-01-01 00:00:00+00', FALSE,
     (SELECT id FROM zones WHERE zone_code = 'APEX_TOWER'));


-- =============================================================================
-- 2. zone_bosses
-- Boss Aethers guarding each zone. Defeating them is part of zone progression.
-- Depends on: zones, aether_species, item_definitions
-- =============================================================================
CREATE TABLE zone_bosses (
    id              SERIAL          PRIMARY KEY,
    zone_id         INTEGER         NOT NULL REFERENCES zones(id),
    boss_code       VARCHAR(40)     NOT NULL UNIQUE,
    display_name    VARCHAR(100)    NOT NULL,
    description     TEXT,
    boss_order      SMALLINT        NOT NULL DEFAULT 1,  -- order within the zone (1 = first boss)
    is_main_boss    BOOLEAN         NOT NULL DEFAULT FALSE,
    species_id      INTEGER         NOT NULL REFERENCES aether_species(id),
    boss_level      SMALLINT        NOT NULL CHECK (boss_level BETWEEN 1 AND 100),
    hp_multiplier   NUMERIC(4,2)    NOT NULL DEFAULT 1.50, -- HP pool vs normal instance
    reward_item_id  INTEGER         REFERENCES item_definitions(id),
    reward_exp      INTEGER         NOT NULL DEFAULT 500,
    reward_currency INTEGER         NOT NULL DEFAULT 200,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

INSERT INTO zone_bosses
    (zone_id, boss_code, display_name, description, boss_order, is_main_boss, species_id, boss_level, hp_multiplier, reward_item_id, reward_exp, reward_currency)
VALUES
    -- Velvet District
    ((SELECT id FROM zones WHERE zone_code = 'VELVET_DISTRICT'),
     'BOSS_VELVET_SHADE', 'The Shade', 'A phantom Noctara that rules the Velvet rooftops.',
     1, FALSE,
     (SELECT id FROM aether_species WHERE species_code = 'NOCTARA'),
     18, 1.50,
     (SELECT id FROM item_definitions WHERE item_code = 'SILK_BIND'),
     800, 300),

    ((SELECT id FROM zones WHERE zone_code = 'VELVET_DISTRICT'),
     'BOSS_VELVET_LORD', 'Lord Nocterion', 'The apex Noir ruler of the Velvet District. Final gatekeeper.',
     2, TRUE,
     (SELECT id FROM aether_species WHERE species_code = 'NOCTERION'),
     25, 2.00,
     (SELECT id FROM item_definitions WHERE item_code = 'LUXE_LURE'),
     2000, 800),

    -- Soleil Coast
    ((SELECT id FROM zones WHERE zone_code = 'SOLEIL_COAST'),
     'BOSS_SOLEIL_RADIANT', 'The Radiant', 'A blazing Solarius that emerged from a solar storm.',
     1, FALSE,
     (SELECT id FROM aether_species WHERE species_code = 'SOLARIUS'),
     18, 1.50,
     (SELECT id FROM item_definitions WHERE item_code = 'SILK_BIND'),
     800, 300),

    ((SELECT id FROM zones WHERE zone_code = 'SOLEIL_COAST'),
     'BOSS_SOLEIL_APEX', 'Solarius Prime', 'The coastal champion. Burns anything that challenges it.',
     2, TRUE,
     (SELECT id FROM aether_species WHERE species_code = 'SOLARIUS_X'),
     25, 2.00,
     (SELECT id FROM item_definitions WHERE item_code = 'BLOOM_STONE'),
     2000, 800),

    -- Neon Undercity
    ((SELECT id FROM zones WHERE zone_code = 'NEON_UNDERCITY'),
     'BOSS_NEON_SURGE', 'Surge', 'An overcharged Ravlet that controls the Undercity power grid.',
     1, TRUE,
     (SELECT id FROM aether_species WHERE species_code = 'RAVLET'),
     22, 2.00,
     (SELECT id FROM item_definitions WHERE item_code = 'FOCUS_CRYSTAL'),
     1500, 600),

    -- Bloom Gardens
    ((SELECT id FROM zones WHERE zone_code = 'BLOOM_GARDENS'),
     'BOSS_BLOOM_ELDER', 'Elder Aurath', 'An ancient Aurath that has meditated in the Gardens for decades.',
     1, TRUE,
     (SELECT id FROM aether_species WHERE species_code = 'AURATH'),
     28, 2.00,
     (SELECT id FROM item_definitions WHERE item_code = 'AURA_PRISM'),
     1800, 700),

    -- Grim Quarters
    ((SELECT id FROM zones WHERE zone_code = 'GRIM_QUARTERS'),
     'BOSS_GRIM_REAPER', 'The Reaper', 'A Grimkin that has grown impossibly powerful in the fog.',
     1, TRUE,
     (SELECT id FROM aether_species WHERE species_code = 'GRIMKIN'),
     30, 2.00,
     (SELECT id FROM item_definitions WHERE item_code = 'GRIM_SHARD'),
     2000, 800),

    -- Apex Tower
    ((SELECT id FROM zones WHERE zone_code = 'APEX_TOWER'),
     'BOSS_APEX_FINAL', 'The Apex Sovereign', 'The ultimate boss. A Grandluxe of impossible power.',
     1, TRUE,
     (SELECT id FROM aether_species WHERE species_code = 'GRANDLUXE'),
     60, 3.00,
     (SELECT id FROM item_definitions WHERE item_code = 'MASTER_WEAVE'),
     10000, 5000);


-- =============================================================================
-- 3. zone_unlock_rules
-- Conditions that must ALL be true simultaneously to unlock a zone.
-- Multiple rows for the same zone = AND logic (all must pass).
-- Depends on: zones (two FKs — the zone being unlocked and optionally a required zone)
-- =============================================================================
CREATE TABLE zone_unlock_rules (
    id                  SERIAL          PRIMARY KEY,
    unlocks_zone_id     INTEGER         NOT NULL REFERENCES zones(id),
    condition_type      VARCHAR(30)     NOT NULL
                            CHECK (condition_type IN (
                                'BOSS_DEFEATED',    -- a specific boss must be beaten
                                'FOCUS_SESSIONS',   -- N focus sessions completed
                                'STREAK_DAYS',      -- N day streak maintained
                                'ZONE_COMPLETED',   -- another zone fully cleared
                                'PLAYER_LEVEL',     -- player level reached
                                'ITEM_OWNED'        -- player owns a specific item
                            )),
    condition_value     VARCHAR(50)     NOT NULL,  -- boss_code, count, item_code, etc.
    required_zone_id    INTEGER         REFERENCES zones(id),  -- for ZONE_COMPLETED condition
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT now()
);

INSERT INTO zone_unlock_rules (unlocks_zone_id, condition_type, condition_value, required_zone_id)
VALUES
    -- Neon Undercity: beat Velvet District main boss + 5 focus sessions + 3 day streak
    ((SELECT id FROM zones WHERE zone_code = 'NEON_UNDERCITY'), 'BOSS_DEFEATED',  'BOSS_VELVET_LORD',  NULL),
    ((SELECT id FROM zones WHERE zone_code = 'NEON_UNDERCITY'), 'FOCUS_SESSIONS', '5',                 NULL),
    ((SELECT id FROM zones WHERE zone_code = 'NEON_UNDERCITY'), 'STREAK_DAYS',    '3',                 NULL),

    -- Bloom Gardens: beat Soleil Coast main boss + 5 focus sessions
    ((SELECT id FROM zones WHERE zone_code = 'BLOOM_GARDENS'),  'BOSS_DEFEATED',  'BOSS_SOLEIL_APEX',  NULL),
    ((SELECT id FROM zones WHERE zone_code = 'BLOOM_GARDENS'),  'FOCUS_SESSIONS', '5',                 NULL),

    -- Grim Quarters: Neon Undercity completed + 7 day streak
    ((SELECT id FROM zones WHERE zone_code = 'GRIM_QUARTERS'),  'ZONE_COMPLETED', 'NEON_UNDERCITY',
     (SELECT id FROM zones WHERE zone_code = 'NEON_UNDERCITY')),
    ((SELECT id FROM zones WHERE zone_code = 'GRIM_QUARTERS'),  'STREAK_DAYS',    '7',                 NULL),

    -- Wilde Outskirts: Bloom Gardens completed + 10 focus sessions
    ((SELECT id FROM zones WHERE zone_code = 'WILDE_OUTSKIRTS'), 'ZONE_COMPLETED', 'BLOOM_GARDENS',
     (SELECT id FROM zones WHERE zone_code = 'BLOOM_GARDENS')),
    ((SELECT id FROM zones WHERE zone_code = 'WILDE_OUTSKIRTS'), 'FOCUS_SESSIONS', '10',               NULL),

    -- Aura Sanctum: player level 15 + 14 day streak
    ((SELECT id FROM zones WHERE zone_code = 'AURA_SANCTUM'),   'PLAYER_LEVEL',   '15',                NULL),
    ((SELECT id FROM zones WHERE zone_code = 'AURA_SANCTUM'),   'STREAK_DAYS',    '14',                NULL),

    -- Ironclad Foundry: Grim Quarters completed + player level 15
    ((SELECT id FROM zones WHERE zone_code = 'IRONCLAD_FOUNDRY'), 'ZONE_COMPLETED', 'GRIM_QUARTERS',
     (SELECT id FROM zones WHERE zone_code = 'GRIM_QUARTERS')),
    ((SELECT id FROM zones WHERE zone_code = 'IRONCLAD_FOUNDRY'), 'PLAYER_LEVEL',   '15',              NULL),

    -- Vex Labyrinth: Wilde Outskirts completed + Aura Sanctum completed
    ((SELECT id FROM zones WHERE zone_code = 'VEX_LABYRINTH'),  'ZONE_COMPLETED', 'WILDE_OUTSKIRTS',
     (SELECT id FROM zones WHERE zone_code = 'WILDE_OUTSKIRTS')),
    ((SELECT id FROM zones WHERE zone_code = 'VEX_LABYRINTH'),  'ZONE_COMPLETED', 'AURA_SANCTUM',
     (SELECT id FROM zones WHERE zone_code = 'AURA_SANCTUM')),

    -- Apex Tower: ALL previous zones completed + 30 day streak + player level 30
    ((SELECT id FROM zones WHERE zone_code = 'APEX_TOWER'),     'ZONE_COMPLETED', 'VEX_LABYRINTH',
     (SELECT id FROM zones WHERE zone_code = 'VEX_LABYRINTH')),
    ((SELECT id FROM zones WHERE zone_code = 'APEX_TOWER'),     'ZONE_COMPLETED', 'IRONCLAD_FOUNDRY',
     (SELECT id FROM zones WHERE zone_code = 'IRONCLAD_FOUNDRY')),
    ((SELECT id FROM zones WHERE zone_code = 'APEX_TOWER'),     'STREAK_DAYS',    '30',                NULL),
    ((SELECT id FROM zones WHERE zone_code = 'APEX_TOWER'),     'PLAYER_LEVEL',   '30',                NULL);


-- =============================================================================
-- 4. quests
-- Quest definitions. Each quest belongs to a zone and has a type.
-- Depends on: zones, item_definitions
-- =============================================================================
CREATE TABLE quests (
    id                  SERIAL          PRIMARY KEY,
    quest_code          VARCHAR(40)     NOT NULL UNIQUE,
    zone_id             INTEGER         NOT NULL REFERENCES zones(id),
    title               VARCHAR(150)    NOT NULL,
    description         TEXT,
    quest_type          VARCHAR(20)     NOT NULL
                            CHECK (quest_type IN (
                                'MAIN',         -- critical story path
                                'SIDE',         -- optional, zone flavour
                                'DAILY',        -- resets every day
                                'FACTION',      -- tied to a faction rank
                                'FOCUS'         -- requires real-world focus sessions
                            )),
    is_repeatable       BOOLEAN         NOT NULL DEFAULT FALSE,
    exp_reward          INTEGER         NOT NULL DEFAULT 0,
    currency_reward     INTEGER         NOT NULL DEFAULT 0,
    item_reward_id      INTEGER         REFERENCES item_definitions(id),
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT now()
);

INSERT INTO quests
    (quest_code, zone_id, title, description, quest_type, is_repeatable, exp_reward, currency_reward, item_reward_id)
VALUES
    -- Velvet District — Main quests
    ('Q_VD_01', (SELECT id FROM zones WHERE zone_code = 'VELVET_DISTRICT'),
     'First Threads', 'Choose your starter Aether and learn the basics of binding.',
     'MAIN', FALSE, 200, 100, NULL),

    ('Q_VD_02', (SELECT id FROM zones WHERE zone_code = 'VELVET_DISTRICT'),
     'The Missing Shipment', 'A Luxe-type smuggler has stolen a shipment of Bind Threads. Track them down.',
     'MAIN', FALSE, 400, 200,
     (SELECT id FROM item_definitions WHERE item_code = 'SILK_BIND')),

    ('Q_VD_03', (SELECT id FROM zones WHERE zone_code = 'VELVET_DISTRICT'),
     'Velvet Throne', 'Challenge Lord Nocterion and claim the Velvet District for your faction.',
     'MAIN', FALSE, 1000, 500,
     (SELECT id FROM item_definitions WHERE item_code = 'LUXE_LURE')),

    -- Velvet District — Side quests
    ('Q_VD_S01', (SELECT id FROM zones WHERE zone_code = 'VELVET_DISTRICT'),
     'Stray in the Alley', 'A Grimkin has been spotted lurking near the boutiques. Help or capture it.',
     'SIDE', FALSE, 150, 80, NULL),

    ('Q_VD_S02', (SELECT id FROM zones WHERE zone_code = 'VELVET_DISTRICT'),
     'Night Shift', 'The district is quieter at night. Explore after dark and report what you find.',
     'SIDE', FALSE, 200, 100, NULL),

    -- Velvet District — Focus quest
    ('Q_VD_F01', (SELECT id FROM zones WHERE zone_code = 'VELVET_DISTRICT'),
     'Binder''s Study', 'A veteran Binder challenges you — complete 3 focus sessions to prove your dedication.',
     'FOCUS', FALSE, 300, 150,
     (SELECT id FROM item_definitions WHERE item_code = 'FOCUS_CRYSTAL')),

    -- Velvet District — Daily
    ('Q_VD_D01', (SELECT id FROM zones WHERE zone_code = 'VELVET_DISTRICT'),
     'Daily Patrol', 'Patrol the Velvet District and report any unusual Aether activity.',
     'DAILY', TRUE, 100, 50, NULL),

    -- Soleil Coast — Main quests
    ('Q_SC_01', (SELECT id FROM zones WHERE zone_code = 'SOLEIL_COAST'),
     'Tide Watchers', 'The coastal Binders need help monitoring an unusual solar phenomenon.',
     'MAIN', FALSE, 400, 200, NULL),

    ('Q_SC_02', (SELECT id FROM zones WHERE zone_code = 'SOLEIL_COAST'),
     'Solarius Rising', 'Solarius Prime has been spotted. Face it before it destabilises the coast.',
     'MAIN', FALSE, 1000, 500,
     (SELECT id FROM item_definitions WHERE item_code = 'BLOOM_STONE')),

    -- Soleil Coast — Focus quest
    ('Q_SC_F01', (SELECT id FROM zones WHERE zone_code = 'SOLEIL_COAST'),
     'Dawn Discipline', 'The Soleil Collective demands 5 focus sessions at dawn to join their ranks.',
     'FOCUS', FALSE, 400, 200,
     (SELECT id FROM item_definitions WHERE item_code = 'AETHER_CHARM')),

    -- Neon Undercity — Main quests
    ('Q_NU_01', (SELECT id FROM zones WHERE zone_code = 'NEON_UNDERCITY'),
     'Pulse Check', 'The Undercity''s power grid is fluctuating. Find the Ravlet causing the surges.',
     'MAIN', FALSE, 500, 250, NULL),

    ('Q_NU_02', (SELECT id FROM zones WHERE zone_code = 'NEON_UNDERCITY'),
     'Neon Crown', 'Defeat Surge and stabilise the Undercity power network.',
     'MAIN', FALSE, 1200, 600,
     (SELECT id FROM item_definitions WHERE item_code = 'FOCUS_CRYSTAL')),

    -- Bloom Gardens — Main quest
    ('Q_BG_01', (SELECT id FROM zones WHERE zone_code = 'BLOOM_GARDENS'),
     'The Wilting', 'Something is draining energy from the Gardens. Elder Aurath is weakening.',
     'MAIN', FALSE, 600, 300, NULL),

    ('Q_BG_02', (SELECT id FROM zones WHERE zone_code = 'BLOOM_GARDENS'),
     'Root Cause', 'Confront Elder Aurath and restore balance to the Bloom Gardens.',
     'MAIN', FALSE, 1500, 700,
     (SELECT id FROM item_definitions WHERE item_code = 'AURA_PRISM')),

    -- Grim Quarters — Main quest
    ('Q_GQ_01', (SELECT id FROM zones WHERE zone_code = 'GRIM_QUARTERS'),
     'Into the Fog', 'Investigate the source of the Grim Fog and confront what lurks within.',
     'MAIN', FALSE, 800, 400, NULL),

    ('Q_GQ_02', (SELECT id FROM zones WHERE zone_code = 'GRIM_QUARTERS'),
     'The Reaping', 'Face The Reaper and lift the fog from Grim Quarters.',
     'MAIN', FALSE, 2000, 1000,
     (SELECT id FROM item_definitions WHERE item_code = 'GRIM_SHARD')),

    -- Apex Tower — Final quest
    ('Q_AT_01', (SELECT id FROM zones WHERE zone_code = 'APEX_TOWER'),
     'The Summit', 'Ascend Apex Tower and face the Apex Sovereign. The ultimate test of a Binder.',
     'MAIN', FALSE, 10000, 5000,
     (SELECT id FROM item_definitions WHERE item_code = 'MASTER_WEAVE'));


-- =============================================================================
-- 5. quest_stages
-- Ordered stages within each quest. has_choice = branching stage.
-- Depends on: quests
-- =============================================================================
CREATE TABLE quest_stages (
    id              SERIAL          PRIMARY KEY,
    quest_id        INTEGER         NOT NULL REFERENCES quests(id),
    stage_order     SMALLINT        NOT NULL,
    title           VARCHAR(150)    NOT NULL,
    objective_type  VARCHAR(30)     NOT NULL
                        CHECK (objective_type IN (
                            'TALK',             -- talk to an NPC
                            'CATCH',            -- catch a specific species
                            'DEFEAT',           -- defeat a specific boss or Aether
                            'COLLECT',          -- collect N of an item
                            'FOCUS',            -- complete N focus sessions
                            'EXPLORE',          -- visit a location
                            'DELIVER'           -- bring item to NPC
                        )),
    objective_value VARCHAR(100)    NOT NULL,  -- species_code, boss_code, item_code, count, etc.
    has_choice      BOOLEAN         NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    UNIQUE (quest_id, stage_order)
);

INSERT INTO quest_stages (quest_id, stage_order, title, objective_type, objective_value, has_choice)
VALUES
    -- Q_VD_01: First Threads
    ((SELECT id FROM quests WHERE quest_code = 'Q_VD_01'), 1, 'Meet the Veteran Binder', 'TALK',    'NPC_VETERAN_BINDER', FALSE),
    ((SELECT id FROM quests WHERE quest_code = 'Q_VD_01'), 2, 'Choose Your Starter',     'CATCH',   'STARTER_CHOICE',     TRUE),
    ((SELECT id FROM quests WHERE quest_code = 'Q_VD_01'), 3, 'First Battle',            'DEFEAT',  'WILD_GRIMKIN',       FALSE),

    -- Q_VD_02: The Missing Shipment
    ((SELECT id FROM quests WHERE quest_code = 'Q_VD_02'), 1, 'Investigate the Docks',   'EXPLORE', 'VELVET_DOCKS',       FALSE),
    ((SELECT id FROM quests WHERE quest_code = 'Q_VD_02'), 2, 'Confront the Smuggler',   'DEFEAT',  'SMUGGLER_NOCTARA',   FALSE),
    ((SELECT id FROM quests WHERE quest_code = 'Q_VD_02'), 3, 'Recover the Shipment',    'COLLECT', 'BIND_THREAD:3',      FALSE),
    ((SELECT id FROM quests WHERE quest_code = 'Q_VD_02'), 4, 'Return or Keep?',         'DELIVER', 'BIND_THREAD',        TRUE),

    -- Q_VD_03: Velvet Throne
    ((SELECT id FROM quests WHERE quest_code = 'Q_VD_03'), 1, 'Reach the Rooftop',       'EXPLORE', 'VELVET_ROOFTOP',     FALSE),
    ((SELECT id FROM quests WHERE quest_code = 'Q_VD_03'), 2, 'Defeat The Shade',        'DEFEAT',  'BOSS_VELVET_SHADE',  FALSE),
    ((SELECT id FROM quests WHERE quest_code = 'Q_VD_03'), 3, 'Face Lord Nocterion',     'DEFEAT',  'BOSS_VELVET_LORD',   FALSE),
    ((SELECT id FROM quests WHERE quest_code = 'Q_VD_03'), 4, 'Claim the District',      'TALK',    'NPC_FACTION_ENVOY',  TRUE),

    -- Q_VD_S01: Stray in the Alley
    ((SELECT id FROM quests WHERE quest_code = 'Q_VD_S01'), 1, 'Find the Grimkin',        'EXPLORE', 'VELVET_ALLEY',      FALSE),
    ((SELECT id FROM quests WHERE quest_code = 'Q_VD_S01'), 2, 'Help or Capture?',        'CATCH',   'GRIMKIN',           TRUE),

    -- Q_VD_F01: Binder's Study
    ((SELECT id FROM quests WHERE quest_code = 'Q_VD_F01'), 1, 'Accept the Challenge',    'TALK',    'NPC_VETERAN_BINDER',FALSE),
    ((SELECT id FROM quests WHERE quest_code = 'Q_VD_F01'), 2, 'Complete Focus Sessions', 'FOCUS',   '3',                 FALSE),
    ((SELECT id FROM quests WHERE quest_code = 'Q_VD_F01'), 3, 'Report Back',             'TALK',    'NPC_VETERAN_BINDER',FALSE),

    -- Q_SC_01: Tide Watchers
    ((SELECT id FROM quests WHERE quest_code = 'Q_SC_01'), 1, 'Meet the Collective',      'TALK',    'NPC_SOLEIL_WATCHER',FALSE),
    ((SELECT id FROM quests WHERE quest_code = 'Q_SC_01'), 2, 'Catch a Solara',           'CATCH',   'SOLARA',            FALSE),
    ((SELECT id FROM quests WHERE quest_code = 'Q_SC_01'), 3, 'Monitor the Coast',        'EXPLORE', 'SOLEIL_LIGHTHOUSE', FALSE),

    -- Q_SC_02: Solarius Rising
    ((SELECT id FROM quests WHERE quest_code = 'Q_SC_02'), 1, 'Reach the Solar Spire',    'EXPLORE', 'SOLAR_SPIRE',       FALSE),
    ((SELECT id FROM quests WHERE quest_code = 'Q_SC_02'), 2, 'Defeat Solarius Prime',    'DEFEAT',  'BOSS_SOLEIL_APEX',  FALSE),
    ((SELECT id FROM quests WHERE quest_code = 'Q_SC_02'), 3, 'Stabilise the Coast',      'TALK',    'NPC_SOLEIL_WATCHER',TRUE),

    -- Q_SC_F01: Dawn Discipline
    ((SELECT id FROM quests WHERE quest_code = 'Q_SC_F01'), 1, 'Join the Dawn Sessions',  'TALK',    'NPC_DAWN_MASTER',   FALSE),
    ((SELECT id FROM quests WHERE quest_code = 'Q_SC_F01'), 2, 'Complete Dawn Sessions',  'FOCUS',   '5',                 FALSE),
    ((SELECT id FROM quests WHERE quest_code = 'Q_SC_F01'), 3, 'Receive Blessing',        'TALK',    'NPC_DAWN_MASTER',   FALSE),

    -- Q_NU_01: Pulse Check
    ((SELECT id FROM quests WHERE quest_code = 'Q_NU_01'), 1, 'Enter the Undercity',      'EXPLORE', 'NEON_GATE',         FALSE),
    ((SELECT id FROM quests WHERE quest_code = 'Q_NU_01'), 2, 'Find the Power Node',      'EXPLORE', 'NEON_POWER_NODE',   FALSE),
    ((SELECT id FROM quests WHERE quest_code = 'Q_NU_01'), 3, 'Catch the Ravlet',         'CATCH',   'RAVLET',            FALSE),

    -- Q_NU_02: Neon Crown
    ((SELECT id FROM quests WHERE quest_code = 'Q_NU_02'), 1, 'Reach the Grid Core',      'EXPLORE', 'NEON_GRID_CORE',    FALSE),
    ((SELECT id FROM quests WHERE quest_code = 'Q_NU_02'), 2, 'Defeat Surge',             'DEFEAT',  'BOSS_NEON_SURGE',   FALSE),
    ((SELECT id FROM quests WHERE quest_code = 'Q_NU_02'), 3, 'Restore the Grid',         'TALK',    'NPC_CIRCUIT_CHIEF', TRUE),

    -- Q_AT_01: The Summit
    ((SELECT id FROM quests WHERE quest_code = 'Q_AT_01'), 1, 'Reach the Tower Base',     'EXPLORE', 'APEX_BASE',         FALSE),
    ((SELECT id FROM quests WHERE quest_code = 'Q_AT_01'), 2, 'Ascend the Floors',        'DEFEAT',  'APEX_GAUNTLET',     FALSE),
    ((SELECT id FROM quests WHERE quest_code = 'Q_AT_01'), 3, 'Face the Sovereign',       'DEFEAT',  'BOSS_APEX_FINAL',   FALSE),
    ((SELECT id FROM quests WHERE quest_code = 'Q_AT_01'), 4, 'Claim Your Legacy',        'TALK',    'NPC_APEX_HERALD',   TRUE);


-- =============================================================================
-- 6. quest_stage_outcomes
-- Outcomes for stages with has_choice = TRUE.
-- Each row = one selectable option. Sets a world flag and optionally changes faction rep.
-- Depends on: quest_stages, factions
-- =============================================================================
CREATE TABLE quest_stage_outcomes (
    id                      SERIAL          PRIMARY KEY,
    stage_id                INTEGER         NOT NULL REFERENCES quest_stages(id),
    choice_option           VARCHAR(50)     NOT NULL,   -- e.g. 'KEEP', 'RETURN', 'CATCH', 'HELP'
    display_label           VARCHAR(100)    NOT NULL,   -- shown to player in UI
    sets_flag_key           VARCHAR(60),                -- flag written to player_world_flags
    sets_flag_value         VARCHAR(50),                -- value of that flag
    reputation_faction_id   INTEGER         REFERENCES factions(id),
    reputation_change       INTEGER         NOT NULL DEFAULT 0,
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT now(),
    UNIQUE (stage_id, choice_option)
);

INSERT INTO quest_stage_outcomes
    (stage_id, choice_option, display_label, sets_flag_key, sets_flag_value, reputation_faction_id, reputation_change)
VALUES
    -- Q_VD_01 Stage 2: Choose Your Starter
    ((SELECT qs.id FROM quest_stages qs JOIN quests q ON q.id = qs.quest_id
      WHERE q.quest_code = 'Q_VD_01' AND qs.stage_order = 2),
     'CHOOSE_NOIR',   'Choose Noctelle (Noir)',   'starter_chosen', 'NOCTELLE', NULL, 0),

    ((SELECT qs.id FROM quest_stages qs JOIN quests q ON q.id = qs.quest_id
      WHERE q.quest_code = 'Q_VD_01' AND qs.stage_order = 2),
     'CHOOSE_SOLEIL', 'Choose Solara (Soleil)',   'starter_chosen', 'SOLARA',   NULL, 0),

    ((SELECT qs.id FROM quest_stages qs JOIN quests q ON q.id = qs.quest_id
      WHERE q.quest_code = 'Q_VD_01' AND qs.stage_order = 2),
     'CHOOSE_LUXE',   'Choose Luxkin (Luxe)',     'starter_chosen', 'LUXKIN',   NULL, 0),

    -- Q_VD_02 Stage 4: Return or Keep the shipment?
    ((SELECT qs.id FROM quest_stages qs JOIN quests q ON q.id = qs.quest_id
      WHERE q.quest_code = 'Q_VD_02' AND qs.stage_order = 4),
     'RETURN', 'Return the shipment to its owner',
     'vd_shipment_returned', 'true',
     (SELECT id FROM factions WHERE faction_code = 'THE_VELVET_SYNDICATE'), 50),

    ((SELECT qs.id FROM quest_stages qs JOIN quests q ON q.id = qs.quest_id
      WHERE q.quest_code = 'Q_VD_02' AND qs.stage_order = 4),
     'KEEP', 'Keep the shipment for yourself',
     'vd_shipment_kept', 'true',
     (SELECT id FROM factions WHERE faction_code = 'THE_VELVET_SYNDICATE'), -30),

    -- Q_VD_03 Stage 4: Claim the District — which faction gets it?
    ((SELECT qs.id FROM quest_stages qs JOIN quests q ON q.id = qs.quest_id
      WHERE q.quest_code = 'Q_VD_03' AND qs.stage_order = 4),
     'SYNDICATE', 'Give control to The Velvet Syndicate',
     'vd_faction_control', 'SYNDICATE',
     (SELECT id FROM factions WHERE faction_code = 'THE_VELVET_SYNDICATE'), 100),

    ((SELECT qs.id FROM quest_stages qs JOIN quests q ON q.id = qs.quest_id
      WHERE q.quest_code = 'Q_VD_03' AND qs.stage_order = 4),
     'INDEPENDENT', 'Keep the district independent',
     'vd_faction_control', 'INDEPENDENT',
     NULL, 0),

    -- Q_VD_S01 Stage 2: Help or Capture the Grimkin?
    ((SELECT qs.id FROM quest_stages qs JOIN quests q ON q.id = qs.quest_id
      WHERE q.quest_code = 'Q_VD_S01' AND qs.stage_order = 2),
     'HELP',    'Feed and release the Grimkin',
     'vd_stray_helped', 'true',
     (SELECT id FROM factions WHERE faction_code = 'GRIM_BROTHERHOOD'), 20),

    ((SELECT qs.id FROM quest_stages qs JOIN quests q ON q.id = qs.quest_id
      WHERE q.quest_code = 'Q_VD_S01' AND qs.stage_order = 2),
     'CAPTURE', 'Capture the Grimkin',
     'vd_stray_captured', 'true',
     NULL, 0),

    -- Q_SC_02 Stage 3: How to stabilise the coast?
    ((SELECT qs.id FROM quest_stages qs JOIN quests q ON q.id = qs.quest_id
      WHERE q.quest_code = 'Q_SC_02' AND qs.stage_order = 3),
     'COLLECTIVE', 'Hand authority to the Soleil Collective',
     'sc_coast_authority', 'COLLECTIVE',
     (SELECT id FROM factions WHERE faction_code = 'SOLEIL_COLLECTIVE'), 100),

    ((SELECT qs.id FROM quest_stages qs JOIN quests q ON q.id = qs.quest_id
      WHERE q.quest_code = 'Q_SC_02' AND qs.stage_order = 3),
     'INDEPENDENT', 'Leave the coast unaffiliated',
     'sc_coast_authority', 'INDEPENDENT',
     NULL, 0),

    -- Q_NU_02 Stage 3: Who controls the grid?
    ((SELECT qs.id FROM quest_stages qs JOIN quests q ON q.id = qs.quest_id
      WHERE q.quest_code = 'Q_NU_02' AND qs.stage_order = 3),
     'NEON_CIRCUIT', 'Hand the grid to Neon Circuit',
     'nu_grid_control', 'NEON_CIRCUIT',
     (SELECT id FROM factions WHERE faction_code = 'NEON_CIRCUIT'), 100),

    ((SELECT qs.id FROM quest_stages qs JOIN quests q ON q.id = qs.quest_id
      WHERE q.quest_code = 'Q_NU_02' AND qs.stage_order = 3),
     'INDEPENDENT', 'Keep the grid public',
     'nu_grid_control', 'INDEPENDENT',
     NULL, 0),

    -- Q_AT_01 Stage 4: Claim your legacy
    ((SELECT qs.id FROM quest_stages qs JOIN quests q ON q.id = qs.quest_id
      WHERE q.quest_code = 'Q_AT_01' AND qs.stage_order = 4),
     'APEX_ORDER', 'Join the Apex Order',
     'apex_allegiance', 'APEX_ORDER',
     (SELECT id FROM factions WHERE faction_code = 'APEX_ORDER'), 200),

    ((SELECT qs.id FROM quest_stages qs JOIN quests q ON q.id = qs.quest_id
      WHERE q.quest_code = 'Q_AT_01' AND qs.stage_order = 4),
     'FREE_BINDER', 'Remain a Free Binder',
     'apex_allegiance', 'FREE_BINDER',
     NULL, 0);


-- =============================================================================
-- 7. quest_unlock_conditions
-- Gates that must be true before a quest becomes visible to the player.
-- Multiple rows for same quest = AND logic.
-- Depends on: quests
-- =============================================================================
CREATE TABLE quest_unlock_conditions (
    id              SERIAL          PRIMARY KEY,
    quest_id        INTEGER         NOT NULL REFERENCES quests(id),
    condition_type  VARCHAR(20)     NOT NULL
                        CHECK (condition_type IN (
                            'FLAG',         -- a world flag must equal a value
                            'QUEST_DONE',   -- another quest must be completed
                            'PLAYER_LEVEL', -- player must be a minimum level
                            'STREAK_DAYS',  -- must have an active streak
                            'ZONE_UNLOCKED' -- a zone must be unlocked first
                        )),
    flag_key        VARCHAR(60),    -- used when condition_type = 'FLAG'
    required_value  VARCHAR(50)     NOT NULL,  -- the value that must match / threshold
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

INSERT INTO quest_unlock_conditions (quest_id, condition_type, flag_key, required_value)
VALUES
    -- Q_VD_02 unlocks after Q_VD_01 is done
    ((SELECT id FROM quests WHERE quest_code = 'Q_VD_02'), 'QUEST_DONE', NULL, 'Q_VD_01'),

    -- Q_VD_03 unlocks after Q_VD_02 is done
    ((SELECT id FROM quests WHERE quest_code = 'Q_VD_03'), 'QUEST_DONE', NULL, 'Q_VD_02'),

    -- Q_VD_S01 unlocks after Q_VD_01 is done
    ((SELECT id FROM quests WHERE quest_code = 'Q_VD_S01'), 'QUEST_DONE', NULL, 'Q_VD_01'),

    -- Q_VD_F01 unlocks after Q_VD_01 is done
    ((SELECT id FROM quests WHERE quest_code = 'Q_VD_F01'), 'QUEST_DONE', NULL, 'Q_VD_01'),

    -- Q_VD_D01 (daily) unlocks after Q_VD_01 is done
    ((SELECT id FROM quests WHERE quest_code = 'Q_VD_D01'), 'QUEST_DONE', NULL, 'Q_VD_01'),

    -- Q_SC_02 unlocks after Q_SC_01 and Soleil Coast zone is unlocked
    ((SELECT id FROM quests WHERE quest_code = 'Q_SC_02'), 'QUEST_DONE',    NULL, 'Q_SC_01'),

    -- Q_SC_F01 unlocks after Q_SC_01
    ((SELECT id FROM quests WHERE quest_code = 'Q_SC_F01'), 'QUEST_DONE',   NULL, 'Q_SC_01'),

    -- Q_NU_02 unlocks after Q_NU_01
    ((SELECT id FROM quests WHERE quest_code = 'Q_NU_02'), 'QUEST_DONE',    NULL, 'Q_NU_01'),

    -- Q_BG_02 unlocks after Q_BG_01
    ((SELECT id FROM quests WHERE quest_code = 'Q_BG_02'), 'QUEST_DONE',    NULL, 'Q_BG_01'),

    -- Q_GQ_02 unlocks after Q_GQ_01
    ((SELECT id FROM quests WHERE quest_code = 'Q_GQ_02'), 'QUEST_DONE',    NULL, 'Q_GQ_01'),

    -- Q_AT_01 requires all main zone quests done + 30 day streak
    ((SELECT id FROM quests WHERE quest_code = 'Q_AT_01'), 'QUEST_DONE',    NULL, 'Q_GQ_02'),
    ((SELECT id FROM quests WHERE quest_code = 'Q_AT_01'), 'QUEST_DONE',    NULL, 'Q_BG_02'),
    ((SELECT id FROM quests WHERE quest_code = 'Q_AT_01'), 'STREAK_DAYS',   NULL, '30'),
    ((SELECT id FROM quests WHERE quest_code = 'Q_AT_01'), 'ZONE_UNLOCKED', NULL, 'APEX_TOWER');


-- =============================================================================
-- 8. world_state_flag_definitions
-- Master registry of all flag keys used in the quest system.
-- Purely documentary — the engine reads player_world_flags at runtime.
-- quest_stage_outcomes write flags; quest_unlock_conditions read them.
-- Depends on: zones
-- =============================================================================
CREATE TABLE world_state_flag_definitions (
    id              SERIAL          PRIMARY KEY,
    flag_key        VARCHAR(60)     NOT NULL UNIQUE,
    zone_id         INTEGER         REFERENCES zones(id),  -- zone this flag belongs to
    possible_values TEXT            NOT NULL,              -- comma-separated valid values
    description     TEXT,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

INSERT INTO world_state_flag_definitions (flag_key, zone_id, possible_values, description)
VALUES
    ('starter_chosen',
     (SELECT id FROM zones WHERE zone_code = 'VELVET_DISTRICT'),
     'NOCTELLE,SOLARA,LUXKIN',
     'Which starter Aether the player chose at the beginning.'),

    ('vd_shipment_returned',
     (SELECT id FROM zones WHERE zone_code = 'VELVET_DISTRICT'),
     'true,false',
     'Whether the player returned the stolen shipment in Q_VD_02.'),

    ('vd_shipment_kept',
     (SELECT id FROM zones WHERE zone_code = 'VELVET_DISTRICT'),
     'true,false',
     'Whether the player kept the stolen shipment in Q_VD_02.'),

    ('vd_faction_control',
     (SELECT id FROM zones WHERE zone_code = 'VELVET_DISTRICT'),
     'SYNDICATE,INDEPENDENT',
     'Which faction controls the Velvet District after Q_VD_03.'),

    ('vd_stray_helped',
     (SELECT id FROM zones WHERE zone_code = 'VELVET_DISTRICT'),
     'true,false',
     'Whether the player helped the stray Grimkin in Q_VD_S01.'),

    ('vd_stray_captured',
     (SELECT id FROM zones WHERE zone_code = 'VELVET_DISTRICT'),
     'true,false',
     'Whether the player captured the stray Grimkin in Q_VD_S01.'),

    ('sc_coast_authority',
     (SELECT id FROM zones WHERE zone_code = 'SOLEIL_COAST'),
     'COLLECTIVE,INDEPENDENT',
     'Who controls the Soleil Coast after Q_SC_02.'),

    ('nu_grid_control',
     (SELECT id FROM zones WHERE zone_code = 'NEON_UNDERCITY'),
     'NEON_CIRCUIT,INDEPENDENT',
     'Who controls the Neon Undercity power grid after Q_NU_02.'),

    ('apex_allegiance',
     (SELECT id FROM zones WHERE zone_code = 'APEX_TOWER'),
     'APEX_ORDER,FREE_BINDER',
     'The player''s final allegiance choice at the end of Q_AT_01.');

-- =============================================================================
-- END V003__phase1_story_systems.sql
-- =============================================================================
