-- ============================================================
-- fix: search_profile_by_handle 의 relation 분기 버그
-- ============================================================
-- 기존 CASE 는 friendship row 가 아예 없는 (left join NULL) 경우에도
-- ELSE 'pending_received' 로 떨어져서, 처음 검색한 사용자에게도
-- "거절/수락" 버튼이 노출되는 문제가 있었다.
--
-- NULL 판별을 case 의 첫 분기로 두어 'none' 을 명시 반환한다.
-- COALESCE 는 더 이상 필요 없다 (CASE 가 항상 비-NULL 을 반환).
create or replace function search_profile_by_handle(
  search_nickname text,
  search_tag text
)
returns table (id uuid, nickname text, tag text, relation text)
language sql
security definer
set search_path = public
as $$
  select
    p.id,
    p.nickname,
    p.tag,
    case
      when f.user_id is null then 'none'
      when f.status = 'accepted' then 'accepted'
      when f.requested_by = auth.uid() then 'pending_sent'
      else 'pending_received'
    end as relation
  from profiles p
  left join friendships f
    on f.user_id = auth.uid()
   and f.friend_id = p.id
  where auth.uid() is not null
    and p.id <> auth.uid()
    and p.nickname = search_nickname
    and p.tag = search_tag
  limit 1;
$$;
