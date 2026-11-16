# Case Closed

﻿CASE CLOSED는 플레이어가 수사관이 되어9명의 용의자를 차례로 심문하는 심리 추리 게임입니다. 플레이어는 용의자에게 자유 텍스트 입력을 통한 심문, 증거제시 등의 방법을 사용하여 용의자의 자백 또는 붕괴를 이끌어 내는 것을 목표로 합니다.


## 프로젝트 개요

- **장르**: 텍스트 어드벤처 / 심리 추리 게임
- **엔진**: Godot 4.6 (GDScript)
- **실행 파일**: `build/windows/CaseClosed.exe` 
- **포스터 PDF**: `documents/CaseClosed_포스터.pdf` 
- **프로젝트 결과 보고서 PDF**:`documents/CaseClosed_결과_보고서.pdf` 
- **시연 영상**: https://app.notion.com/p/CaseClosed-41aba558b08d80c5a987e46064bd4089?source=copy_link

## 개발 환경

- OS: Windows 10/11
- 엔진: Godot 4.6.2 (mono 빌드)
- 외부 API: Anthropic Claude API (`claude-haiku-5-5`) — 실행 전 `ANTHROPIC_API_KEY` 환경변수 필요

## 기술 스택

- **Godot 4 / GDScript** — 전체 게임 로직
- **Claude API (Messages API)** — 발언 기법 분류와 용의자 반응 대사 생성
- **HTTPRequest** — 별도 SDK 없이 Godot 내장 노드로 직접 API 호출
- **Resource(.tres)** — 용의자별 스탯/임계값/자백조건, 증거 데이터를 코드와 분리해 관리
- **ConfigFile** — 스테이지 진행 상황 저장

## 주요 특징

- **기법 버튼 없음** — 플레이어는 자유 텍스트로 말하고, LLM이 10가지 심문 기법 중 하나로 분류
- **수치는 코드가 계산** — 경계심/라포/자존심/진술 붕괴도 변화는 LLM이 아니라 로직이 담당
- **각기 다른 용의자** — 각자 다른 스탯, 종료 임계값, 자백 특수조건을 가짐
- **두 가지 자백 경로** — 마음을 열어 털어놓는 라포 경로와, 거짓말이 무너져 인정하는 붕괴 경로 중 유리한
  쪽을 찾아야 함
- **증거 시스템** — 실제 증거 제시, 가짜 증거 간파, 특정 용의자 전용 증거 조합(드래그 앤 드롭)

## 게임 흐름

```
타이틀 화면 (새 게임 / 이어하기 / 설정 / 나가기)
	↓
Stage 1부터 순서대로 9명의 용의자를 심문
	↓ (각 스테이지)
지속형 심문 화면 — 증거 확인·발언 제출을 자유롭게 오가며 최대 10회 행동
	↓
자백 성공 → 다음 스테이지로 진행
실패(경계심 임계점 초과 / 행동 소진) → 같은 스테이지 재시도
	↓
Stage 9까지 전부 자백받으면 게임 클리어
```

## 시작 가이드

1. 저장소 클론
   ```
   git clone https://github.com/jukame1224/Case-Closed.git
   ```
2. [Godot 4.6.2](https://godotengine.org/download) 설치
3. [console.anthropic.com](https://console.anthropic.com)에서 API 키 발급 후, 시스템 환경변수
   `ANTHROPIC_API_KEY`로 영구 등록 (키는 절대 코드/리소스에 직접 넣지 않는다)
4. Godot 에디터에서 프로젝트 폴더의 `project.godot` 열기
5. 상단 재생 버튼(또는 F5)으로 `Main.tscn` 실행
