# 3D 모드 광원 효과 · 바닥 텍스처 설계

작성일: 2026-05-30

## 목표

1인칭 3D 미로(`claude-opus-4-8`, FMX)에 분위기 있는 광원 효과를 추가한다.

- 벽에 횃불을 일정 간격(2칸)으로 배치하고 실제로 주변을 밝히는 조명을 넣는다.
- 바닥에 석재 타일 텍스처를 추가한다.

모든 변경은 `Maze.Scene.pas` 안에서 처리한다. `MainForm.pas`는 이미 매 프레임
`FScene.Update(LDt)`를 호출하므로 수정하지 않는다.

## 제약: FMX 라이트 개수 한계

FMX 3D 셰이더는 동시 활성 라이트 수가 제한(통상 8개)된다. 미로는 최대 40×40 이라
횃불마다 `TLight`를 두면 수백 개가 되어 렌더가 깨지거나 일부만 적용된다.
따라서 **하이브리드** 방식을 쓴다.

## 1. 바닥 석재 텍스처

- `CreateStoneFloorTexture` 추가 → `FFloorBitmap: TBitmap`(256×256) 생성.
- 어두운 회색 돌 타일 격자(예: 4×4 타일) + 타일별 미세 명도 차이 + 줄눈(어두운 선) +
  점 노이즈로 질감. `CreateBrickTexture`와 동일한 캔버스 패턴.
- `FFloorMaterial.Texture := FFloorBitmap`. 바닥 면이 넓으므로 비트맵 자체에 여러 타일을
  그려 큰 면에서도 디테일이 보이게 한다(`TLightMaterialSource`는 UV 반복 미지원).

## 2. 벽 횃불 (하이브리드 조명)

### 비주얼
- 2칸 간격 셀의 벽에 `브래킷(어두운 작은 실린더/큐브) + 불꽃(주황 발광 Sphere)`을 배치.
- 불꽃은 강한 Emissive 머티리얼(`FFlameMaterial`)로 항상 빛나 보인다.
- 모든 횃불 월드 좌표를 `FTorchPoints: TList<TPoint3D>`에, 불꽃 오브젝트를
  `FFlameObjects: TList<TControl3D>`에 저장.

### 배치 규칙
- `BuildTorches`: 셀을 순회하며 `(X mod 2 = 0) and (Y mod 2 = 0)` 인 셀에서, 그 셀이 가진
  벽(`WallsAt`) 중 하나를 골라 그 벽 면에 횃불을 붙인다(불꽃은 열린 칸 쪽으로 약간 돌출).
  벽이 없는 셀은 건너뛴다.

### 실제 조명 (라이트 풀링)
- `FTorchLights: TList<TLight>` — 6개 포인트 라이트 풀 생성.
- 기존 `FTorch`(카메라 헤드램프)는 유지 → 총 7개, 8개 한계 이내.
- `UpdateTorchLights`: 카메라(`FCamera`) 위치 기준 가장 가까운 횃불 6곳을 찾아 풀 라이트를
  그 위치로 재배치. 멀어진 횃불은 발광만, 가까운 횃불은 주변 벽·바닥을 실제로 밝힌다.

### 깜빡임
- `FFlicker: Single` 시간 누적. 불꽃 Emissive 밝기/스케일과 풀 라이트 밝기를 사인 + 의사난수
  조합으로 살짝 흔들어 횃불 느낌을 준다.

## 3. 인터페이스 변화

- `Update(const ADt: Single)` 시그니처 유지. 내부에서 코인 회전 갱신에 더해
  `UpdateTorchLights`(플레이어 위치는 `FCamera`에서 읽음)와 깜빡임 갱신을 수행.
- `Clear`/`Destroy`에서 새 필드 정리(비트맵 해제, 리스트 정리, nil 설정).
- 생성자에서 `CreateStoneFloorTexture` 호출, 리스트 생성.

## 새 멤버 요약

필드: `FFloorBitmap`, `FTorchPoints`, `FTorchLights`, `FFlameObjects`,
`FFlameMaterial`, `FBracketMaterial`, `FFlicker`.

메서드: `CreateStoneFloorTexture`, `BuildTorches`, `UpdateTorchLights`.

## 테스트/검증

- `dcc64`로 컴파일 성공.
- 실행하여 (a) 바닥에 돌 타일이 보이는지, (b) 벽에 횃불이 일정 간격으로 빛나는지,
  (c) 플레이어가 다가가면 주변이 실제로 밝아지고 멀어지면 어두워지는지, (d) 불꽃이
  깜빡이는지 육안 확인.
