-- Extend the message_type check constraint to include find_me and meetup_point.
-- The original constraint (021) only allowed 'text' and 'location_ping'.
alter table trip_messages
  drop constraint if exists trip_messages_message_type_check;

alter table trip_messages
  add constraint trip_messages_message_type_check
    check (message_type in ('text', 'location_ping', 'find_me', 'meetup_point'));
