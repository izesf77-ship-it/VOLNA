# VOLNA — Catalog Benchmark (100 queries)

**Purpose:** measure real catalog behavior per provider and classify results honestly.  
**Method:** run each query against every enabled provider (search), inspect returned tracks, and where possible validate stream availability/format/Range. AVPlayer playback/seek requires iOS runtime and is not executable in this Windows environment.

## Classification
- **FULL_STREAM** — on-demand full track with playable stream URL, valid duration (>=60s unless explicitly short/intro), not preview.
- **PREVIEW** — limited fragment (typically ~30s) or explicitly preview-only stream.
- **METADATA_ONLY** — metadata/artwork without a usable in-app playback stream.
- **BROKEN** — stream/endpoint unavailable, invalid, or non-playable for AVPlayer.
- **WRONG_MATCH** — result does not match requested artist/title intent.
- **DUPLICATE** — same recording/version already counted (ISRC or normalized artist+title+duration).

## 100 queries

### Русская музыка / поп / рэп / рок / новые и старые
1. MACAN
2. Miyagi & Andy Panda
3. Miyagi & Эндшпиль
4. Скриптонит
5. Баста
6. Ноггано
7. ANNA ASTI
8. Artik & Asti
9. Три дня дождя
10. Zivert
11. Егор Крид
12. HammAli & Navai
13. Noize MC
14. Oxxxymiron
15. Кино
16. Виктор Цой
17. Би-2
18. Сплин
19. Земфира
20. ДДТ
21. Мумий Тролль
22. t.A.T.u.
23. Глюкоза
24. МакSим
25. Полина Гагарина
26. JONY
27. Ramil'
28. 10AGE
29. GAYAZOV$ BROTHER$
30. INSTASAMKA
31. Mona
32. XOLIDAYBOY
33. Niletto
34. Markul
35. Pharaoh
36. Boulevard Depo
37. kizaru
38. Big Baby Tape
39. FEDUK
40. Элджей
41. Мот
42. Тимати
43. Григорий Лепс
44. Михаил Круг
45. Стас Михайлов
46. Любе
47. Король и Шут
48. Ария
49. Порнофильмы
50. Монеточка

### Зарубежный хип-хоп / поп / рок / электроника / инди / старые / новые
51. The Weeknd
52. Drake
53. Travis Scott
54. Eminem
55. Billie Eilish
56. Rihanna
57. Dua Lipa
58. Kendrick Lamar
59. Linkin Park
60. Daft Punk
61. Post Malone
62. Kanye West
63. Jay-Z
64. SZA
65. Doja Cat
66. Taylor Swift
67. Ed Sheeran
68. Adele
69. Coldplay
70. Imagine Dragons
71. Arctic Monkeys
72. Radiohead
73. Nirvana
74. Queen
75. Michael Jackson
76. Madonna
77. David Bowie
78. The Beatles
79. Pink Floyd
80. Metallica
81. AC/DC
82. Red Hot Chili Peppers
83. Gorillaz
84. The Prodigy
85. Calvin Harris
86. Avicii
87. Swedish House Mafia
88. Depeche Mode
89. Massive Attack
90. Moby
91. Lana Del Rey
92. Frank Ocean
93. Tyler, The Creator
94. A$AP Rocky
95. 21 Savage
96. Metro Boomin
97. Olivia Rodrigo
98. Tame Impala
99. Florence + The Machine
100. NewJeans

## Per-provider result template

| Provider | Query | Total results | FULL_STREAM | PREVIEW | METADATA_ONLY | BROKEN | WRONG_MATCH | DUPLICATE | Notes |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|

## Aggregate summary template

| Provider | Queries with any result | Total raw results | FULL_STREAM | PREVIEW | METADATA_ONLY | BROKEN | WRONG_MATCH | DUPLICATE | Unique playable (est.) | RU coverage notes |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|

## Execution status (this environment)
- Benchmark **not executed** in this session: no iOS runtime/AVPlayer, limited time for 100xN provider live checks, Audius blocked by Cloudflare from this environment, and some gateway routes slow/preview-only.
- Recommended execution: run on macOS runner or device with network access, capture HTTP status, Content-Type, Content-Length/Range support, resolved stream URL, duration, and AVPlayer readiness/seek for sampled FULL_STREAM candidates. Keep live API smoke runs separate from unit tests.