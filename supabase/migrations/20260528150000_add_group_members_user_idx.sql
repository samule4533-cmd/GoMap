-- ============================================================
-- group_members(user_id) 인덱스
-- ============================================================
-- group_members PK 는 (group_id, user_id) 이라 leading column 이 group_id 다.
-- list_my_groups() 는 where gm.user_id = auth.uid() 로 내 그룹을 찾는데,
-- 이 조건은 composite PK 의 후행 column 만 사용하므로 PK 인덱스를 효율적으로
-- 타지 못한다. user_id 단독 인덱스를 추가해 내 그룹 조회를 안정화한다.
create index group_members_user_id_idx on group_members(user_id);
