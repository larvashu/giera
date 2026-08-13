# Giera

Prototyp turowej gry taktycznej 3D tworzony w Godot 4.7.

## Uruchomienie

1. Otworz katalog projektu w Godot 4.7.
2. Poczekaj na zaimportowanie zasobow.
3. Uruchom scene glowna (F5).

Projekt zawiera tryb taktyczny oraz eksploracje pierwszoosobowa, kreator postaci i druzyn, hotseat, system inicjatywy, ruch po siatce oraz proceduralnie dekorowana lesna arene.

## Sterowanie w walce

- LPM: wybor jednostki, pola lub akcji
- 1-9: wybor umiejetnosci
- Spacja: zakonczenie tury
- T: siatka taktyczna
- Tab: przelaczenie trybu taktycznego i eksploracji
- Esc: powrot do menu

## Eksploracja

- WASD: ruch
- Shift: szybszy ruch
- Shift + R: sprint
- Spacja: skok
- Ctrl: kucanie
- PPM + ruch myszy: rozgladanie
- F: pochodnia

## Postacie

Aktualnie dostepne postacie (14): warrior, archer, mage, priest, rogue, druid, golem, troll, dragon, falconer, undead_priest, bandit, ogre, strider.

Postacie z modelem 3D z Meshy AI: **strider**, **undead_priest**, **ogre**.
Pozostale uzyja placeholdera (cylinder) do czasu importu modelu.

Aby dodac nowa postac — patrz `docs/adding_characters.md`.

## Architektura postaci 3D

Kazda postac z modelem 3D sklada sie z:
- `assets/characters/<nazwa>/` — modele GLB (mesh + animacje z Meshy AI)
- `data/characters/<nazwa>.tres` — CharacterDefinition (statystyki + referencje do assetow)

Pipeline importu: **Meshy AI → Meshy Bridge → imported_models/ → Character Importer → assets/characters/**

Szczegoly: `docs/adding_characters.md`
