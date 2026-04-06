insert into facility_types (code, name, description)
values
    ('21', 'Discussion Room', 'Discussion room type used across multiple libraries.'),
    ('23', 'Study Space', 'Study tabletype used in Main Library and in Law Library.'),
    ('29', 'Study Room', 'Study room type used in Chi Wah Learning Commons.'),
    ('30', 'Single Study Room (Medical)', 'Single study room type used in Medical Library.'),
    ('31', 'Single Study Room (Main)', 'Single study room type used in Main Library.'),
    ('33', 'Computer in LTC', 'Computer in LTC type used in Main Library.'),
    ('34', 'Studio and Editing Room', 'Studio and editing room type used in Main Library.'),
    ('35', 'Concept and Creation Room', 'Concept and creation room type used in Main Library.'),
    ('56', 'Study Booth', 'Study booth type used in Chi Wah Learning Commons.')
on conflict (code) do update
set
    name = excluded.name,
    description = excluded.description;

alter table facilities
    add column if not exists x_coordinate double precision,
    add column if not exists y_coordinate double precision,
    add column if not exists width double precision,
    add column if not exists height double precision;

alter table facilities
    alter column x_coordinate set default 0,
    alter column y_coordinate set default 0,
    alter column width set default 10,
    alter column height set default 10;

update facilities
set
    x_coordinate = coalesce(x_coordinate, 0),
    y_coordinate = coalesce(y_coordinate, 0),
    width = coalesce(width, 10),
    height = coalesce(height, 10)
where x_coordinate is null
   or y_coordinate is null
   or width is null
   or height is null;

alter table facilities
    alter column x_coordinate set not null,
    alter column y_coordinate set not null,
    alter column width set not null,
    alter column height set not null;

insert into libraries (legacy_code, name, location, campus, description, opening_hours, latitude, longitude)
values
    ('3', 'Main Library', null, null, 'Includes an overnight area available from 17:00 to 08:00 the next day.', '09:00-17:00; overnight area 17:00-08:00 next day', 22.2832614254766, 114.13773611812404),
    ('6', 'Lui Che Woo Law Library', '1-2/F Cheng Yu Tung Tower', null, null, '09:00-17:00', 22.283282992765464, 114.13383543488779),
    ('4', 'Music Library', '11/F Run Run Shaw Tower', null, null, '08:00-23:00', 22.283656470916362, 114.13439816701072),
    ('8', 'Yu Chun Keung Medical Library', 'LG1 William MW Mong Block', null, 'Includes a 24-hour overnight area.', '09:00-17:00; overnight area 24 hours', 22.2672232789928, 114.12852071081022),
    ('5', 'Chi Wah Learning Commons', null, null, null, 'Mon-Sun 08:00-06:00 next day', 22.283542664339684, 114.1347124794357)
on conflict (legacy_code) do update
set
    name = excluded.name,
    location = excluded.location,
    campus = excluded.campus,
    description = excluded.description,
    opening_hours = excluded.opening_hours,
    latitude = excluded.latitude,
    longitude = excluded.longitude;

with alias_seed (legacy_code, alias) as (
    values
        ('3', 'main library'),
        ('3', 'main'),
        ('3', 'ml'),
        ('3', 'main lib'),
        ('5', 'chi wah learning commons'),
        ('5', 'chi wah'),
        ('5', 'chiwah'),
        ('5', 'chi-wah'),
        ('5', 'cw'),
        ('5', 'cwlc'),
        ('5', 'chi wah commons'),
        ('6', 'law library'),
        ('6', 'law'),
        ('6', 'll'),
        ('6', 'law lib'),
        ('6', 'lui che woo law library'),
        ('8', 'medical library'),
        ('8', 'medical'),
        ('8', 'med'),
        ('8', 'med library'),
        ('8', 'med lib'),
        ('8', 'yu chun keung medical library'),
        ('4', 'music library'),
        ('4', 'music'),
        ('4', 'music lib')
)
insert into library_aliases (library_id, alias)
select
    libraries.id,
    alias_seed.alias
from alias_seed
join libraries on libraries.legacy_code = alias_seed.legacy_code
on conflict (alias) do update
set
    library_id = excluded.library_id;

with facility_seed (
    legacy_code,
    facility_type_code,
    display_type,
    name_prefix,
    capacity,
    start_no,
    end_no,
    excluded_room_nos,
    open_time,
    close_time,
    slot_interval_minutes,
    floor
) as (
    values
        ('3', '21', 'Discussion Room', 'Discussion Room', 4, 126, 129, null::int[], '09:00:00', '17:00:00', 60, 3),
        ('3', '21', 'Discussion Room', 'Discussion Room', 4, 1041, 1041, null::int[], '09:00:00', '17:00:00', 60, 3),
        ('3', '21', 'Discussion Room', 'Discussion Room', 4, 131, 133, null::int[], '09:00:00', '17:00:00', 60, 3),
        ('3', '21', 'Discussion Room', 'Discussion Room', 4, 135, 144, null::int[], '09:00:00', '17:00:00', 60, 3),

        ('3', '33', 'Computer in LTC', 'Computer in LTC', 1, 533, 534, null::int[], '09:00:00', '17:00:00', 60, 2),
        ('3', '33', 'Computer in LTC', 'Computer in LTC', 1, 538, 541, null::int[], '09:00:00', '17:00:00', 60, 2),
        ('3', '33', 'Computer in LTC', 'Computer in LTC', 1, 542, 542, null::int[], '09:00:00', '17:00:00', 60, 2),
        ('3', '33', 'Computer in LTC', 'Computer in LTC', 1, 544, 544, null::int[], '09:00:00', '17:00:00', 60, 2),
        ('3', '33', 'Computer in LTC', 'Computer in LTC', 1, 547, 548, null::int[], '09:00:00', '17:00:00', 60, 2),

        ('3', '34', 'Studio and Editing Room', 'Editing Room', 4, 537, 537, null::int[], '09:00:00', '17:00:00', 60, 2),
        ('3', '35', 'Concept and Creation Room', 'CC Room', 4, 549, 553, null::int[], '09:00:00', '17:00:00', 60, 2),
        ('3', '31', 'Single Study Room', 'Single Study Room', 1, 398, 408, null::int[], '09:00:00', '17:00:00', 60, 4),

        ('3', '23', 'Study Table', 'Study Table', 1, 334, 342, null::int[], '09:00:00', '17:00:00', 60, 4),
        ('3', '23', 'Study Table', 'Study Table', 1, 343, 343, null::int[], '09:00:00', '17:00:00', 60, 4),
        ('3', '23', 'Study Table', 'Study Table', 1, 344, 344, null::int[], '09:00:00', '17:00:00', 60, 4),
        ('3', '23', 'Study Table', 'Study Table', 1, 345, 397, null::int[], '09:00:00', '17:00:00', 60, 4),
        ('3', '23', 'Study Table', 'Study Table', 1, 1037, 1038, null::int[], '09:00:00', '17:00:00', 60, 4),

        ('5', '29', 'Study Room', 'Study Room', 4, 258, 261, null::int[], '08:00:00', '23:59:00', 60, 1),
        ('5', '29', 'Study Room', 'Study Room', 4, 263, 266, null::int[], '08:00:00', '23:59:00', 60, 1),
        ('5', '29', 'Study Room', 'Study Room', 4, 268, 271, null::int[], '08:00:00', '23:59:00', 60, 2),
        ('5', '29', 'Study Room', 'Study Room', 4, 274, 275, null::int[], '08:00:00', '23:59:00', 60, 2),
        ('5', '56', 'Study Booth', 'Study Booth', 1, 1059, 1059, null::int[], '08:00:00', '23:00:00', 60, 1),
        ('5', '56', 'Study Booth', 'Study Booth', 1, 1061, 1063, null::int[], '08:00:00', '23:00:00', 60, 1),

        ('6', '23', 'Study Table', 'Study Table', 1, 411, 437, null::int[], '09:00:00', '17:00:00', 60, 2),
        ('6', '23', 'Study Table', 'Study Table', 1, 438, 438, null::int[], '09:00:00', '17:00:00', 60, 2),
        ('6', '23', 'Study Table', 'Study Table', 1, 439, 439, null::int[], '09:00:00', '17:00:00', 60, 2),
        ('6', '23', 'Study Table', 'Study Table', 1, 440, 477, null::int[], '09:00:00', '17:00:00', 60, 2),
        ('6', '23', 'Study Table', 'Study Table', 1, 478, 478, null::int[], '09:00:00', '17:00:00', 60, 2),
        ('6', '23', 'Study Table', 'Study Table', 1, 479, 479, null::int[], '09:00:00', '17:00:00', 60, 2),
        ('6', '23', 'Study Table', 'Study Table', 1, 480, 480, null::int[], '09:00:00', '17:00:00', 60, 2),
        ('6', '23', 'Study Table', 'Study Table', 1, 482, 499, null::int[], '09:00:00', '17:00:00', 60, 2),
        ('6', '21', 'Discussion Room', 'Discussion Room', 4, 281, 286, null::int[], '09:00:00', '17:00:00', 60, 2),

        ('8', '21', 'Discussion Room', 'Discussion Room', 4, 501, 506, null::int[], '09:00:00', '17:00:00', 60, 0),
        ('8', '30', 'Single Study Room', 'ALG', 1, 532, 532, null::int[], '09:00:00', '17:00:00', 60, 0),
        ('8', '30', 'Single Study Room', 'ALG', 1, 628, 629, null::int[], '09:00:00', '17:00:00', 60, 0),
        ('8', '30', 'Single Study Room', 'ALG', 1, 632, 632, null::int[], '09:00:00', '17:00:00', 60, 0),

        ('4', '21', 'Discussion Room', 'Discussion Room', 4, 313, 315, null::int[], '08:00:00', '23:00:00', 60, 11)
)
insert into facilities (
    library_id,
    room_code,
    facility_type_code,
    name,
    type,
    capacity,
    open_time,
    close_time,
    slot_interval_minutes,
    floor,
    x_coordinate,
    y_coordinate,
    width,
    height,
    is_active,
    is_bookable
)
select
    libraries.id,
    generated.room_no::text,
    facility_seed.facility_type_code,
    facility_seed.name_prefix || ' ' || generated.room_no::text,
    facility_seed.display_type,
    facility_seed.capacity,
    facility_seed.open_time::time,
    facility_seed.close_time::time,
    facility_seed.slot_interval_minutes,
    facility_seed.floor,
    0,
    0,
    10,
    10,
    true,
    true
from facility_seed
join libraries on libraries.legacy_code = facility_seed.legacy_code
cross join lateral generate_series(facility_seed.start_no, facility_seed.end_no) as generated(room_no)
where facility_seed.excluded_room_nos is null
   or not (generated.room_no = any(facility_seed.excluded_room_nos))
on conflict (library_id, room_code) do update
set
    facility_type_code = excluded.facility_type_code,
    name = excluded.name,
    type = excluded.type,
    capacity = excluded.capacity,
    open_time = excluded.open_time,
    close_time = excluded.close_time,
    slot_interval_minutes = excluded.slot_interval_minutes,
    floor = excluded.floor,
    x_coordinate = excluded.x_coordinate,
    y_coordinate = excluded.y_coordinate,
    width = excluded.width,
    height = excluded.height,
    is_active = true,
    is_bookable = true;

-- Override generated names with canonical labels from ai_agent/facility_details.txt.
with generated_name_seed (legacy_code, room_code, name) as (
        -- Main Library discussion rooms
        select '3', gs::text, 'Discussion Room ' || (gs - 125)::text from generate_series(126, 129) as gs
        union all
        select '3', '1041', 'Discussion Room 5'
        union all
        select '3', gs::text, 'Discussion Room ' || (gs - 125)::text from generate_series(131, 133) as gs
        union all
        select '3', gs::text, 'Discussion Room ' || (gs - 125)::text from generate_series(135, 144) as gs

        -- Main Library computers, editing room, CC rooms
        union all
        select '3', gs::text, 'iMac ' || (gs - 532)::text from generate_series(533, 534) as gs
        union all
        select '3', gs::text, 'iMac ' || (gs - 535)::text from generate_series(538, 541) as gs
        union all
        select '3', '542', 'PC 1'
        union all
        select '3', '544', 'PC 3'
        union all
        select '3', gs::text, 'PC ' || (gs - 543)::text from generate_series(547, 548) as gs
        union all
        select '3', '537', 'Editing Room 2'
        union all
        select '3', gs::text, 'CC Room ' || (gs - 548)::text from generate_series(549, 553) as gs

        -- Main Library single study rooms (Room 422-428, 432-435)
        union all
        select '3', gs::text, 'Room ' || (gs + 24)::text from generate_series(398, 404) as gs
        union all
        select '3', gs::text, 'Room ' || (gs + 27)::text from generate_series(405, 408) as gs

        -- Main Library study tables
        union all
        select '3', gs::text, 'Study Table ' || (gs - 333)::text from generate_series(334, 342) as gs
        union all
        select '3', '343', 'Study Table 11'
        union all
        select '3', '344', 'Study Table 10'
        union all
        select '3', gs::text, 'Study Table ' || (gs - 333)::text from generate_series(345, 397) as gs
        union all
        select '3', '1037', 'Study Table 65'
        union all
        select '3', '1038', 'Study Table 66'

        -- Chi Wah study rooms and booths
        union all
        select '5', gs::text, 'Study Room ' || (gs - 256)::text from generate_series(258, 261) as gs
        union all
        select '5', gs::text, 'Study Room ' || (gs - 256)::text from generate_series(263, 266) as gs
        union all
        select '5', gs::text, 'Study Room ' || (gs - 256)::text from generate_series(268, 271) as gs
        union all
        select '5', gs::text, 'Study Room ' || (gs - 256)::text from generate_series(274, 275) as gs
        union all
        select '5', '1059', 'Study Booth A'
        union all
        select '5', '1061', 'Study Booth B'
        union all
        select '5', '1062', 'Study Booth C'
        union all
        select '5', '1063', 'Study Booth D'

        -- Law Library study tables and discussion rooms
        union all
        select '6', gs::text, 'Study Table R' || (gs - 410)::text from generate_series(411, 437) as gs
        union all
        select '6', '438', 'Study Table R29'
        union all
        select '6', '439', 'Study Table R28'
        union all
        select '6', gs::text, 'Study Table R' || (gs - 410)::text from generate_series(440, 477) as gs
        union all
        select '6', '478', 'Study Table R69'
        union all
        select '6', '479', 'Study Table R68'
        union all
        select '6', '480', 'Study Table R70'
        union all
        select '6', gs::text, 'Study Table R' || (gs - 411)::text from generate_series(482, 499) as gs
        union all
        select '6', gs::text, 'Discussion Room ' || (gs - 280)::text from generate_series(281, 286) as gs

        -- Medical Library
        union all
        select '8', gs::text, 'Discussion Room ' || (gs - 500)::text from generate_series(501, 506) as gs
        union all
        select '8', '532', 'ALG28'
        union all
        select '8', '632', 'ALG29'
        union all
        select '8', '628', 'ALG30'
        union all
        select '8', '629', 'ALG31'

        -- Music Library
        union all
        select '4', gs::text, 'Discussion Room ' || (gs - 312)::text from generate_series(313, 315) as gs
)
update facilities
set name = generated_name_seed.name
from generated_name_seed
join libraries on libraries.legacy_code = generated_name_seed.legacy_code
where facilities.library_id = libraries.id
    and facilities.room_code = generated_name_seed.room_code;

-- Apply map layout coordinates migrated from legacy Python seeding scripts.
with explicit_layout_seed (legacy_code, room_code, x_coordinate, y_coordinate, width, height) as (
    values
        -- Main Library discussion rooms (legacy Discussion Room 1-8, 10-19)
        ('3', '126', 130, 35, 20, 15),
        ('3', '127', 110, 35, 20, 15),
        ('3', '128', 90, 35, 20, 15),
        ('3', '129', 70, 10, 15, 15),
        ('3', '1041', 55, 10, 15, 15),
        ('3', '131', 40, 10, 15, 15),
        ('3', '132', 25, 10, 15, 15),
        ('3', '133', 10, 10, 15, 20),
        ('3', '135', 10, 50, 15, 15),
        ('3', '136', 10, 65, 15, 20),
        ('3', '137', 25, 70, 15, 15),
        ('3', '138', 40, 70, 15, 15),
        ('3', '139', 55, 70, 15, 15),
        ('3', '140', 70, 70, 15, 15),
        ('3', '141', 90, 50, 15, 15),
        ('3', '142', 105, 50, 15, 15),
        ('3', '143', 120, 50, 15, 15),
        ('3', '144', 135, 50, 15, 15),

        -- Chi Wah Learning Commons study rooms (legacy room number + 256)
        ('5', '258', 110, 30, 15, 15),
        ('5', '259', 95, 30, 15, 15),
        ('5', '260', 80, 10, 15, 15),
        ('5', '261', 60, 30, 15, 15),
        ('5', '263', 25, 30, 15, 15),
        ('5', '264', 10, 30, 15, 15),
        ('5', '265', 35, 60, 15, 15),
        ('5', '266', 50, 60, 15, 15),
        ('5', '268', 70, 30, 15, 15),
        ('5', '269', 45, 10, 15, 15),
        ('5', '270', 45, 30, 15, 15),
        ('5', '271', 20, 25, 15, 15),
        ('5', '274', 45, 55, 15, 15),
        ('5', '275', 45, 70, 15, 15),

        -- Chi Wah study booths (legacy Study Booth A-D)
        ('5', '1059', 73, 43, 15, 15),
        ('5', '1061', 53, 43, 15, 15),
        ('5', '1062', 33, 43, 15, 15),
        ('5', '1063', 13, 43, 15, 15),

        -- Law Library discussion rooms (legacy Discussion Room 1-6 + 280)
        ('6', '281', 65, 25, 15, 15),
        ('6', '282', 50, 25, 15, 15),
        ('6', '283', 35, 10, 15, 15),
        ('6', '284', 10, 10, 25, 15),
        ('6', '285', 10, 25, 15, 15),
        ('6', '286', 10, 40, 15, 15),

        -- Music Library discussion rooms (legacy Discussion Room 1-3 + 312)
        ('4', '313', 40, 10, 20, 20),
        ('4', '314', 40, 40, 20, 20),
        ('4', '315', 40, 70, 20, 20),

        -- Main Library study tables 65 and 66
        ('3', '1037', 70, 160, 10, 10),
        ('3', '1038', 85, 160, 10, 10)
)
update facilities
set
    x_coordinate = explicit_layout_seed.x_coordinate,
    y_coordinate = explicit_layout_seed.y_coordinate,
    width = explicit_layout_seed.width,
    height = explicit_layout_seed.height
from explicit_layout_seed
join libraries on libraries.legacy_code = explicit_layout_seed.legacy_code
where facilities.library_id = libraries.id
  and facilities.room_code = explicit_layout_seed.room_code;

-- Main Library study tables (legacy Study Table 1-64 mapped to room_code 334-397)
update facilities
set
    x_coordinate = 10 + ((facilities.room_code::int - 334) % 6) * 15,
    y_coordinate = 10 + ((facilities.room_code::int - 334) / 6) * 15,
    width = 10,
    height = 10
from libraries
where facilities.library_id = libraries.id
  and libraries.legacy_code = '3'
  and facilities.room_code ~ '^[0-9]+$'
  and facilities.room_code::int between 334 and 397;

-- Law Library study tables (legacy Study Table R1-R88 mapped to room_code 411-499, excluding 481)
update facilities
set
    x_coordinate = 10 + ((facilities.room_code::int - 411) % 6) * 15,
    y_coordinate = 10 + ((facilities.room_code::int - 411) / 6) * 15,
    width = 10,
    height = 10
from libraries
where facilities.library_id = libraries.id
  and libraries.legacy_code = '6'
  and facilities.room_code ~ '^[0-9]+$'
  and facilities.room_code::int between 411 and 499
  and facilities.room_code::int <> 481;

-- Medical Library discussion rooms (legacy Discussion Room 1-6 mapped to room_code 501-506)
update facilities
set
    x_coordinate = 10 + (facilities.room_code::int - 501) * 20,
    y_coordinate = 40,
    width = 15,
    height = 15
from libraries
where facilities.library_id = libraries.id
  and libraries.legacy_code = '8'
  and facilities.room_code ~ '^[0-9]+$'
  and facilities.room_code::int between 501 and 506;


-- Law Library Study Table

-- Main Library Computer in LTC

-- Main Library CC Room

-- Main Library Single Study Room

-- Main Library Studio and Editing Room

-- Main Library Study Table

-- Medical Library Single Study Room
