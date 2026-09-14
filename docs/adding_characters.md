# Dodawanie nowej postaci 3D

Poradnik dla Larvashu i innych kontrybutorów.

## TL;DR

1. Wygeneruj postac w Meshy AI
2. Wyslij animacje przez Meshy Bridge do Godota
3. W edytorze: Character Importer → wpisz nazwe → Import
4. Uzupelnij `.tres` (statystyki, opis)
5. Dodaj zdolnosci do `DEFAULT_ABILITIES` w `unit.gd`

---

## Krok 1 — Wygeneruj postac w Meshy AI

W Meshy AI wygeneruj postac jako **biped** (Character output).
Nastepnie wygeneruj animacje:
- **Idle** (bezczynnosc)
- **Walk** (chodzenie)
- **Run** (bieganie)
- **Attack** (atak)
- **Death** (smierc)
- opcjonalnie: **Hurt** (otrzymanie obrazen)

Animacje moga miec dowolne nazwy w Meshy — plugin rozpoznaje je automatycznie po slowach kluczowych w nazwie pliku.

---

## Krok 2 — Wyslij przez Meshy Bridge

W Meshy kliknij **Send to Godot** dla kazdej animacji osobno (i dla modelu bazowego).
Pliki trafi do staging area `imported_models/` — nie ruszaj ich recznie.

Mozesz sprawdzic log Godota zeby zobaczyc co zostalo pobrane.

---

## Krok 3 — Character Importer

W edytorze Godot znajdz panel **Character Importer** (prawy dolny dok).

1. Kliknij **Odswiez** — pojawi sie lista wykrytych modeli
2. Wpisz nazwe postaci w snake_case, np. `warrior` lub `dark_elf`
3. Kliknij **Import Character**

Plugin automatycznie:
- przenosi pliki z `imported_models/` do `assets/characters/<nazwa>/`
- zmienia nazwy na `<nazwa>.glb`, `<nazwa>_idle.glb`, `<nazwa>_walk.glb` itd.
- tworzy `data/characters/<nazwa>.tres` z domyslnymi statystykami
- wywoluje reimport w Godocie

> Jesli Character Importer nie jest widoczny: Projekt → Wtyczki → wlacz **Character Importer**

---

## Krok 4 — Uzupelnij .tres

Otworz `data/characters/<nazwa>.tres` i uzupelnij:

```
display_name = "Nazwa wyswietlana"
description = "Krotki opis postaci"
role_name = "Rola"
max_health = 12
max_action_points = 6
initiative = 10
movement_range = 6
team_slot_cost = 1
visual_scale = 1.0
visual_rotation_degrees = Vector3(0, 180, 0)
```

Mozesz dostosowac `visual_scale` i `visual_offset` jesli postac jest za duza/mala lub zle wycentrowana.

**Uwaga:** `.tres` wygenerowany przez plugin nie ma UIDs w ext_resource.
Jezeli Godot nie laduje modelu (czerwony pionek), dodaj UIDs recznie — znajdziesz je w plikach `.glb.import` jako pole `uid=`.

---

## Krok 5 — Zdolnosci

Otworz `scripts/units/unit.gd` i dodaj wpis do slownika `DEFAULT_ABILITIES`:

```gdscript
const DEFAULT_ABILITIES: Dictionary = {
    # ...istniejace...
    &"dark_elf": ["Magiczny strzal", "Teleportacja", "Tarcza many"],
}
```

Nazwy zdolnosci musza pasowac do kluczy w `AbilityCatalog` (`scripts/battle/ability_catalog.gd`).
Jesli postac nie ma wpisu — automatycznie dostanie fallback: `["Akcja podstawowa", "Obrona", "Wsparcie"]`.

---

## Struktura assetow

```
assets/characters/<nazwa>/
    <nazwa>.glb                  ← mesh + szkielet (T-pose, Character output z Meshy)
    <nazwa>_idle.glb             ← animacja bezczynnosci (loop)
    <nazwa>_walk.glb             ← animacja chodzenia (loop)
    <nazwa>_run.glb              ← animacja biegu (loop)
    <nazwa>_attack.glb           ← animacja ataku (one-shot)
    <nazwa>_hurt.glb             ← animacja trafienia (one-shot, opcjonalnie)
    <nazwa>_death.glb            ← animacja smierci (one-shot, opcjonalnie)
    *_texture_0.png              ← tekstury (generowane automatycznie przez Godot)

data/characters/<nazwa>.tres     ← CharacterDefinition
```

---

## Zasada ONE MESH + ONE SKELETON

Kazda postac w runtime ma:
- **jeden** MeshInstance3D (z glownego GLB)
- **jeden** Skeleton3D (z glownego GLB)
- **jeden** AnimationPlayer (z glownego GLB)

Animacyjne GLB sa traktowane wylacznie jako zrodlo danych animacji — sa instantiowane tymczasowo, animacja jest kopiowana do glownego AnimationPlayer, a tymczasowa scena jest zwalniana.
Nie pozostaje zaden dodatkowy mesh ani szkielet.

---

## Przyklady gotowych postaci

| Postac | Animacje | Zdolnosci |
|---|---|---|
| strider | idle, walk, run, attack | (fallback) |
| undead_priest | idle, walk, run, attack, death | Dotyk zarazy, Nekrotyczne leczenie, Klatwa grobu |
| ogre | walk, run, attack, alert | Miazdzenie, Ryk, Szarza |

---

## Czego NIE robic

- Nie modyfikuj `TacticalUnit`, `GridManager`, `TurnManager`, `BattleManager` ani `AbilitySystem` zeby dodac postac
- Nie tworzysz osobnych scen dla postaci — caly system dziala przez `CharacterDefinition.tres`
- Nie zmieniaj `CharacterAnimationController` — API jest stabilne
- Nie zostawiaj plikow w `imported_models/` — plugin czysci je automatycznie
