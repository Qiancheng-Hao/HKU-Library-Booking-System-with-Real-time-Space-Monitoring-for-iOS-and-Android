insert into facility_types (code, name, description)
values
    ('21', 'Discussion Room', 'Discussion room type used across multiple libraries.'),
    ('23', 'Study Space', 'Study space code used as study tables in Main Library and study rooms in Law Library.'),
    ('29', 'Study Room', 'Study room type used in Chi Wah Learning Commons.'),
    ('31', 'Single Study Room', 'Single study room type used in Main Library.'),
    ('33', 'Computer in LTC', 'Computer in LTC type used in Main Library.'),
    ('34', 'Studio and Editing Room', 'Studio and editing room type used in Main Library.'),
    ('35', 'Concept and Creation Room', 'Concept and creation room type used in Main Library.')
on conflict (code) do update
set
    name = excluded.name,
    description = excluded.description;

insert into libraries (legacy_code, name, location, campus, description, opening_hours, latitude, longitude)
values
    ('3', 'Main Library', null, null, 'Includes an overnight area available from 17:00 to 08:00 the next day.', '09:00-17:00; overnight area 17:00-08:00 next day', null, null),
    ('6', 'Lui Che Woo Law Library', '1-2/F Cheng Yu Tung Tower', null, null, '09:00-17:00', null, null),
    ('4', 'Music Library', '11/F Run Run Shaw Tower', null, null, '08:00-23:00', null, null),
    ('8', 'Yu Chun Keung Medical Library', 'LG1 William MW Mong Block', null, 'Includes a 24-hour overnight area.', '09:00-17:00; overnight area 24 hours', null, null),
    ('5', 'Chi Wah Learning Commons', null, null, null, 'Mon-Sun 08:00-06:00 next day', null, null)
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
        ('3', '21', 'Discussion Room (3F)', 'Discussion Room', 4, 126, 133, null::int[], '09:00:00', '17:00:00', 60, 3),
        ('3', '21', 'Discussion Room (3F)', 'Discussion Room', 4, 135, 144, null::int[], '09:00:00', '17:00:00', 60, 3),
        ('3', '33', 'Computer in LTC (2F)', 'Computer in LTC', 1, 533, 541, array[537], '09:00:00', '17:00:00', 60, 2),
        ('3', '33', 'Computer in LTC (2F)', 'Computer in LTC', 1, 542, 548, null::int[], '09:00:00', '17:00:00', 60, 2),
        ('3', '34', 'Studio and Editing Room (2F)', 'Studio and Editing Room', 4, 537, 537, null::int[], '09:00:00', '17:00:00', 60, 2),
        ('3', '31', 'Single Study Room (4F)', 'Single Study Room', 1, 398, 404, null::int[], '09:00:00', '17:00:00', 60, 4),
        ('3', '23', 'Study Table (4F)', 'Study Table', 1, 334, 397, null::int[], '09:00:00', '17:00:00', 60, 4),
        ('5', '29', 'Study Room', 'Study Room', 4, 258, 266, null::int[], '08:00:00', '23:59:00', 60, 2),
        ('5', '29', 'Study Room', 'Study Room', 4, 268, 271, null::int[], '08:00:00', '23:59:00', 60, 2),
        ('5', '29', 'Study Room', 'Study Room', 4, 274, 275, null::int[], '08:00:00', '23:59:00', 60, 2),
        ('6', '23', 'Study Room', 'Study Room', 1, 411, 499, null::int[], '09:00:00', '17:00:00', 60, 4),
        ('6', '21', 'Discussion Room', 'Discussion Room', 4, 281, 286, null::int[], '09:00:00', '17:00:00', 60, 2),
        ('8', '21', 'Discussion Room', 'Discussion Room', 4, 501, 506, null::int[], '09:00:00', '17:00:00', 60, 0),
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
    is_active = true,
    is_bookable = true;
