-- Crew "Where's everyone?": check-ins (place, floor, landmark, optional photo,
-- optional map pin) and "where is everyone?" asks — for malls, stations and
-- other places where GPS can't tell people apart.
alter table trip_messages
  drop constraint if exists trip_messages_message_type_check;

alter table trip_messages
  add constraint trip_messages_message_type_check
    check (message_type in ('text', 'location_ping', 'find_me', 'meetup_point',
                            'image', 'check_in', 'where_ask'));
