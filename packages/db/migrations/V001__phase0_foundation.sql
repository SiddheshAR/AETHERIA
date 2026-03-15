-- ================================================================
-- V001 — Phase 0 Foundation
-- Creates the 3 tables everything else depends on:
-- 1. rarity_tiers
-- 2. type_definitions  
-- 3. type_advantages
-- ================================================================

CREATE TABLE rarity_tiers (
    rarity_id           SMALLINT        PRIMARY KEY,
    name                VARCHAR(32)     NOT NULL UNIQUE,
    spawn_rate_pct      DECIMAL(5,2)    NOT NULL,
    catch_difficulty    SMALLINT        NOT NULL,
    trade_value_score   INT             NOT NULL,
    color_hex           VARCHAR(7)      NOT NULL,
    CONSTRAINT chk_catch_difficulty CHECK (catch_difficulty BETWEEN 1 AND 10),
    CONSTRAINT chk_spawn_rate       CHECK (spawn_rate_pct > 0 AND spawn_rate_pct <= 100),
    CONSTRAINT chk_rarity_color     CHECK (color_hex ~ '^#[0-9A-Fa-f]{6}$')
);

INSERT INTO rarity_tiers VALUES
    (1, 'Common',    55.00,  1,   1, '#9E9E9E'),
    (2, 'Rare',      25.00,  3,   3, '#42A5F5'),
    (3, 'Very Rare', 10.00,  5,   8, '#AB47BC'),
    (4, 'Epic',       5.00,  6,  20, '#FF7043'),
    (5, 'Ancient',    3.00,  8,  50, '#FFCA28'),
    (6, 'Legendary',  1.50,  9, 150, '#EF5350'),
    (7, 'God',        0.50, 10, 500, '#E040FB');

CREATE TABLE type_definitions (
    type_id         SMALLINT        PRIMARY KEY,
    type_code       VARCHAR(8)      NOT NULL UNIQUE,
    display_name    VARCHAR(64)     NOT NULL,
    theme_label     VARCHAR(64)     NOT NULL,
    battle_behavior TEXT            NOT NULL,
    color_hex       VARCHAR(7)      NOT NULL,
    icon_key        VARCHAR(64)     NOT NULL,
    description     TEXT            NOT NULL,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    CONSTRAINT chk_type_id_range  CHECK (type_id BETWEEN 1 AND 10),
    CONSTRAINT chk_type_color_hex CHECK (color_hex ~ '^#[0-9A-Fa-f]{6}$')
);

INSERT INTO type_definitions
    (type_id, type_code, display_name, theme_label, battle_behavior, color_hex, icon_key, description)
VALUES
    (1,  'T01', 'Noir',     'Gothic Dark Romance',  'Drains opponent energy with shadowy strikes; excels at debuffs',  '#1A1A2E', 'type_icon_T01', 'Born from midnight thoughts and velvet darkness.'),
    (2,  'T02', 'Soleil',   'Cottagecore Nature',   'Healing and sustain-focused; benefits from rain weather',         '#4CAF50', 'type_icon_T02', 'Rooted in wildflower meadows and morning dew.'),
    (3,  'T03', 'Luxe',     'Victorian Aristocrat', 'High defense and counter-attacks; punishes aggressive opponents', '#C9A84C', 'type_icon_T03', 'Refined through generations of disciplined pursuit.'),
    (4,  'T04', 'Rave',     'Cyberpunk Neon',       'High speed, burst damage; volatile and risky',                   '#E040FB', 'type_icon_T04', 'Wired to the grid, running on signal and static.'),
    (5,  'T05', 'Bloom',    'Kawaii Hyper-Cute',    'Confusion, charm, and evasion; frustrates opponents',            '#F48FB1', 'type_icon_T05', 'Impossibly sweet with a chaotic energy underneath.'),
    (6,  'T06', 'Grim',     'Dark Academia Occult', 'Curse and status effects; builds damage over time',              '#37474F', 'type_icon_T06', 'Pages stained with ink and older things than ink.'),
    (7,  'T07', 'Wilde',    'Punk Anarchist',       'Unpredictable move order; thrives in chaos',                     '#D32F2F', 'type_icon_T07', 'Rules exist to show exactly where to hit.'),
    (8,  'T08', 'Aura',     'Ethereal Celestial',   'Shields, reflects damage, and weather manipulation',             '#81D4FA', 'type_icon_T08', 'Woven from starlight and the spaces between things.'),
    (9,  'T09', 'Ironclad', 'Steampunk Industrial', 'Tankiest type; high guard, chip damage, attrition battles',      '#78909C', 'type_icon_T09', 'Built to last. Slow, deliberate, unstoppable.'),
    (10, 'T10', 'Vex',      'Clowncore Jester',     'Random effects, high variance; can wildly swing battles',        '#FF6F00', 'type_icon_T10', 'Nothing is quite what it seems. Especially the Vex.');

CREATE TABLE type_advantages (
    advantage_id        SERIAL          PRIMARY KEY,
    attacker_type_id    SMALLINT        NOT NULL REFERENCES type_definitions(type_id),
    defender_type_id    SMALLINT        NOT NULL REFERENCES type_definitions(type_id),
    multiplier          DECIMAL(3,2)    NOT NULL,
    CONSTRAINT uq_type_matchup      UNIQUE (attacker_type_id, defender_type_id),
    CONSTRAINT chk_valid_multiplier CHECK (multiplier IN (0.25, 0.50, 1.00, 2.00, 4.00))
);

CREATE INDEX idx_type_advantages_lookup
    ON type_advantages (attacker_type_id, defender_type_id);

INSERT INTO type_advantages (attacker_type_id, defender_type_id, multiplier) VALUES
    (1, 5, 2.00), (1, 2, 2.00), (1, 3, 0.50), (1, 8, 0.50),
    (2, 9, 2.00), (2, 6, 2.00), (2, 1, 0.50), (2, 7, 0.50),
    (3, 1, 2.00), (3, 7, 2.00), (3, 4, 0.50), (3, 10, 0.50),
    (4, 3, 2.00), (4, 9, 2.00), (4, 8, 0.50), (4, 6, 0.50),
    (5, 6, 2.00), (5, 7, 2.00), (5, 1, 0.50), (5, 4, 0.50),
    (6, 8, 2.00), (6, 10, 2.00), (6, 5, 0.50), (6, 2, 0.50),
    (7, 6, 2.00), (7, 3, 2.00), (7, 9, 0.50), (7, 2, 0.50),
    (8, 5, 2.00), (8, 2, 2.00), (8, 1, 0.50), (8, 6, 0.50),
    (9, 4, 2.00), (9, 10, 2.00), (9, 7, 0.50), (9, 2, 0.50),
    (10, 1, 2.00), (10, 8, 2.00), (10, 9, 0.50), (10, 3, 0.50);

DO $$
DECLARE
    type_count      INT;
    advantage_count INT;
    rarity_count    INT;
BEGIN
    SELECT COUNT(*) INTO type_count      FROM type_definitions;
    SELECT COUNT(*) INTO advantage_count FROM type_advantages;
    SELECT COUNT(*) INTO rarity_count    FROM rarity_tiers;

    IF type_count != 10 THEN
        RAISE EXCEPTION 'Expected 10 types, got %', type_count;
    END IF;
    IF advantage_count != 40 THEN
        RAISE EXCEPTION 'Expected 32 matchups, got %', advantage_count;
    END IF;
    IF rarity_count != 7 THEN
        RAISE EXCEPTION 'Expected 7 rarity tiers, got %', rarity_count;
    END IF;

    RAISE NOTICE 'V001 complete — % types, % matchups, % rarity tiers seeded',
        type_count, advantage_count, rarity_count;
END $$;
