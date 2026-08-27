create policy "room members receive realtime" on realtime.messages for select to authenticated
  using (
    exists (
      select 1 from public.room_players p
      where p.room_id = realtime.topic()::uuid and p.user_id = auth.uid()
    )
  );

create policy "room members send realtime" on realtime.messages for insert to authenticated
  with check (
    exists (
      select 1 from public.room_players p
      where p.room_id = realtime.topic()::uuid and p.user_id = auth.uid()
    )
  );
