---
specId: arena-visual-fx
title: 아레나 전투 시각 이펙트
status: queued
owner: partner
runnerProfile: developer
runnerExecution: assistant
createdAt: 2026-04-15
updatedAt: 2026-04-15
dependsOn:
  - phase-5-client-godot
  - phase-3-game-server
  - arena-character-hud
---

# arena-visual-fx: 아레나 전투 시각 이펙트

## 목표
전투 이벤트(공격, 피격, 사망)에 시각적 피드백을 추가하여 게임 몰입감을 높인다. 현재 아레나는 텍스트 로그로만 전투 결과를 표시하며 시각 이펙트가 없다.

## 배경
- `Arena.gd`에서 서버 WS 메시지 수신 시 `combat_log` 이벤트로 전투 결과를 전달받음
- 캐릭터는 `Character.gd`의 Node2D 인스턴스로 아레나에 배치됨
- 이미 캐릭터 위치 정보(`position`, `id`)가 매 턴 GameState에 업데이트됨
- GDScript의 `Tween`/`Line2D`를 활용해 서버 변경 없이 구현 가능

---

## 구현 범위

### 파일: `client/scripts/Arena.gd` (수정)

#### 1. 이펙트 레이어 추가 (`_build_arena_ui()` 안)

```gdscript
var _fx_layer: Node2D  # 이펙트 전용 레이어 (캐릭터 위에 렌더링)

func _build_arena_ui() -> void:
    # 기존 코드 유지 ...
    _fx_layer = Node2D.new()
    _fx_layer.z_index = 10
    add_child(_fx_layer)
```

#### 2. 공격 이펙트 — `_play_attack_fx(from_pos, to_pos, is_ranged)`

```gdscript
func _play_attack_fx(from_pos: Vector2, to_pos: Vector2, is_ranged: bool) -> void:
    var line := Line2D.new()
    line.add_point(from_pos)
    line.add_point(to_pos)
    line.width = 2.0
    line.default_color = Color(1.0, 0.82, 0.2, 0.85) if is_ranged else Color(0.9, 0.3, 0.3, 0.85)
    _fx_layer.add_child(line)

    var tween := create_tween()
    tween.tween_property(line, "modulate:a", 0.0, 0.4)
    tween.tween_callback(line.queue_free)
```

#### 3. 피격 이펙트 — `_play_hit_fx(target_node: Node2D)`

```gdscript
func _play_hit_fx(target_node: Node2D) -> void:
    var original_modulate := target_node.modulate
    var tween := create_tween()
    tween.tween_property(target_node, "modulate", Color(1, 0.3, 0.3), 0.08)
    tween.tween_property(target_node, "modulate", original_modulate, 0.15)
```

#### 4. 사망 이펙트 — `_play_death_fx(target_node: Node2D)`

```gdscript
func _play_death_fx(target_node: Node2D) -> void:
    var tween := create_tween()
    tween.tween_property(target_node, "modulate:a", 0.0, 0.6)
    tween.tween_callback(func(): target_node.modulate.a = 0.25)  # 희미하게 유지
```

#### 5. `_on_turn_result()` — WS 메시지 수신 시 이펙트 재생

```gdscript
func _on_turn_result(data: Dictionary) -> void:
    # 기존 처리 유지
    var events: Array = data.get("events", [])
    for event in events:
        var etype: String = event.get("type", "")
        if etype == "attack" or etype == "ranged_attack":
            var from_node := _get_character_node(event.get("attacker_id", -1))
            var to_node := _get_character_node(event.get("target_id", -1))
            if from_node and to_node:
                _play_attack_fx(from_node.position, to_node.position, etype == "ranged_attack")
                _play_hit_fx(to_node)
        elif etype == "death":
            var dead_node := _get_character_node(event.get("character_id", -1))
            if dead_node:
                _play_death_fx(dead_node)
```

> **주의**: `_on_turn_result` 훅 포인트는 현재 Arena.gd에서 WebSocket 메시지 수신 함수 내에서 처리됨. 실제 이벤트 구조(`events` 배열, `attacker_id`, `target_id`, `character_id`)는 서버 WS 메시지 포맷과 일치해야 함. 불일치 시 `data.get()` 기본값 -1로 안전 처리.

---

## 파일 목록

| 파일 | 변경 내용 |
|------|-----------|
| `client/scripts/Arena.gd` | `_fx_layer` 레이어 추가, `_play_attack_fx()`, `_play_hit_fx()`, `_play_death_fx()`, `_on_turn_result()` 이펙트 연동 |

서버 변경 없음.

---

## 완료 기준 (AC)

| AC | 내용 |
|----|------|
| AC1 | 근접 공격 시 빨간 Line2D 이펙트가 공격자→피격자 사이에 0.4초 페이드 |
| AC2 | 원거리 공격 시 황금색 Line2D 이펙트가 공격자→피격자 사이에 0.4초 페이드 |
| AC3 | 피격 캐릭터가 0.08초 빨간 플래시 → 0.15초 원래 색으로 복귀 |
| AC4 | 사망 캐릭터가 0.6초에 걸쳐 투명해지고 alpha 0.25로 유지 |
| AC5 | 이펙트가 캐릭터 노드 위 레이어(z_index 10)에 렌더링됨 |
| AC6 | 이펙트 재생 중 다음 턴 이벤트 수신 시 충돌 없이 병렬 처리 |

---

## 엣지케이스

| 케이스 | 처리 |
|--------|------|
| 공격자/피격자 노드 없음 | `_get_character_node()` null 반환 시 이펙트 스킵 |
| 동시 다발 이펙트 (32명 전투) | 각 Tween이 독립 인스턴스 → 충돌 없음 |
| 관전 모드 | 동일 로직 동작 (관전자도 이펙트 표시) |
| 빠른 화면 전환 | `queue_free()`로 Tween 완료 후 Line2D 자동 정리 |

---

## 예상 기간
0.5일 (Arena.gd 단일 파일, 서버 없음)
