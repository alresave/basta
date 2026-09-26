-- El estado persistido sólo puede ser modificado por el Host lógico.
create policy "host can persist room snapshot" on public.rooms for update to authenticated
  using (host_id = auth.uid())
  with check (host_id = auth.uid());

-- Cada miembro actualiza únicamente su propia marca de actividad. Esta marca
-- complementa Presence de Realtime cuando una aplicación se cierra sin poder
-- ejecutar un untrack explícito.
create policy "members can update own activity" on public.room_players for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());
