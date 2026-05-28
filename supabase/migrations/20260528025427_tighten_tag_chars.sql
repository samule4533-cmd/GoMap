-- ============================================================
-- profiles.tag 제약 강화
-- ============================================================
-- 기존: # / 공백 문자만 금지 (그 외 모든 문자 허용)
-- 변경: 한글/영문/숫자만 허용 (특수문자 / 이모지 등 전부 차단)
--
-- tag 는 친구 검색의 식별자라 가독성/입력 안정성이 중요하다.
-- nickname 은 표시명이라 자유도를 유지한다 (변경 없음).
alter table profiles
  drop constraint profiles_tag_no_special;

alter table profiles
  add constraint profiles_tag_allowed_chars
    check (tag ~ '^[A-Za-z0-9가-힣]+$');
