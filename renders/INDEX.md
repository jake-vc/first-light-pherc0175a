# Images

Every image is a whole flattened winding of window P (about 2.6 cm tall), the mean z-score of six ink models
(reader-v2, reader-v3, dense_native, ink_9um seeds 42 and 43, Hecate 9.6 µm) in yellow over the dimmed CT, depth 0.
Yellow ramps from z 1.5 to 3.0. 1 cm bar bottom left. `_reading` = the side where ink would be; `_blind` = the side
facing into the next layer, where no ink is expected (the control). Full-resolution versions and the maps are on
Hugging Face under `seg_big/Pf/`.

## Gate: the five strongest flags (preregistered ranking)
| Winding | Reading side | Blind side | Verdict |
|---|---|---|---|
| w114 | [image](gate/w114_reading.png) | [image](gate/w114_blind.png) | not ink |
| w113 | [image](gate/w113_reading.png) | [image](gate/w113_blind.png) | not ink |
| w112 | [image](gate/w112_reading.png) | [image](gate/w112_blind.png) | not ink |
| w103 | [image](gate/w103_reading.png) | [image](gate/w103_blind.png) | not ink |
| w105 | [image](gate/w105_reading.png) | [image](gate/w105_blind.png) | not ink |

## Comparison: the five strongest above their own background
| Winding | Reading side | Blind side | Verdict |
|---|---|---|---|
| w073 | [image](comparison/w073_reading.png) | [image](comparison/w073_blind.png) | not ink |
| w074 | [image](comparison/w074_reading.png) | [image](comparison/w074_blind.png) | not ink |
| w028 | [image](comparison/w028_reading.png) | [image](comparison/w028_blind.png) | not ink |
| w044 | [image](comparison/w044_reading.png) | [image](comparison/w044_blind.png) | not ink |
| w057 | [image](comparison/w057_reading.png) | [image](comparison/w057_blind.png) | not ink |

## PHerc. 343 positive control
- [ctrl_contact_3models.png](control_343/ctrl_contact_3models.png): the three screen models on 343's published
  letter segment, rendered with this project's VC3D build, reading orientation.
- [ctrl_contact.png](control_343/ctrl_contact.png): reader-v3 alone, depths -8..+8.
