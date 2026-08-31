-- =============================================================================
-- WabWay — Migration 039: create_trip_invite — retry on code collision
-- =============================================================================
-- trip_invites.code is UNIQUE. The previous implementation generated a single
-- 8-hex code and failed with unique_violation if it collided. With ~16M possible
-- codes the probability is tiny but non-zero for active trips. This version
-- retries up to 5 times before surfacing a clear error.

create or replace function create_trip_invite(p_trip_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code    text;
  v_attempt int := 0;
begin
  -- Caller must be a trip member.
  if not exists (
    select 1 from trip_members
     where trip_id = p_trip_id
       and user_id = auth.uid()
  ) then
    raise exception 'not_member' using errcode = 'P0001';
  end if;

  loop
    v_attempt := v_attempt + 1;
    v_code    := upper(left(replace(gen_random_uuid()::text, '-', ''), 8));

    begin
      insert into trip_invites (trip_id, code, created_by, expires_at)
      values (
        p_trip_id,
        v_code,
        auth.uid(),
        now() + interval '7 days'
      );
      return v_code;          -- success
    exception
      when unique_violation then
        if v_attempt >= 5 then
          raise exception 'code_collision_exhausted' using errcode = 'P0003';
        end if;
        -- retry with a fresh code
    end;
  end loop;
end;
$$;
