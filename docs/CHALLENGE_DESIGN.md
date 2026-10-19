# Challenge design

Five levels per game; `pickByLevel` changes real parameters (not labels). Seeds are fixed per game so every
child gets the same challenge layout at a given level.

| Game | Mechanic | Level 1 -> 5 changes | Obstacle / decision | Support hooks |
|---|---|---|---|---|
| Jellyfish Catcher | moving targets + distractors, rule switch (blue -> spots) | 6->14 catches, speed 60->130, 2->5 on screen, 0->2 rule changes | wrong jellyfish, targets swimming away (omission) | ring on targets; hint names rule; easier = slower, fewer on screen |
| Hero Shield | choose shield, colour rule swaps (red/blue) | 8->16 hazards, fall 6.5s->3.6s, 0->3 swaps, distractors from L3 | wrong shield, timeout (omission) | ring on correct shield; hint states mapping |
| Rainbow Memory Quest | sequence recall | 4->6 gems, sequence length 2->7, 2->4 rounds | order errors replay the sequence | ring on next gem; demonstration = replay; easier = shorter sequence |
| Turbo Car | 3-lane steering | 10->18 rows, speed .35->.66 rows/s, 1->2 blocked lanes | rocks (gentle bump), always >=1 clear lane | arrows on clear lanes; easier = slower |
| Dino Dash | timed jump, go/no-go with birds | 8->16 obstacles, speed 140->230, gaps 2.2s->1.3s, birds from L3 | jump cactus, stay low for birds | label JUMP / STAY LOW; easier = slower |
| Honey Bee Collector | rule card, ordered collection, rule change halfway | 6->14 flowers, 3x3->4x4 grid, 1->3 colour order | wrong colour/order | ring on needed colour |
| Bird Launcher | drag-and-release physics | 3->5 balloons, size 44->23 px, aim guide off from L3, wall from L4 | gravity arc, wall | ring on target; demonstration = dotted path from a physics solver |
| Sorting Stars | rule switching (colour/shape) | 2->4 rule blocks, cue hidden from L4 | post-switch errors | (uses hint text only) |
| Sleepy Fox | go / no-go | 12->20 items, fox 25%->33%, answer time 2.6s->1.5s | tapping the fox (commission) | |
Older games (Breathing Garden, Bubble Valley, Feelings Memory, Pattern Power, Rainbow Puzzle, Calm Maze,
Bubble Pop Shooter, Happy Connect, Cloud Hop, Peekaboo Pals) keep their v9 mechanics; they are not wired to
game-specific hints yet beyond the shared help button's spoken line.

## v15: four more games with four different mechanics (23 in total)
| Game | Character | What the child does | Why it is different |
|---|---|---|---|
| Carrot Catch | Bubbles | Slides a basket left/right to catch falling food, lets rocks drop | continuous drag; no target tapping |
| Teddy Clinic | Kara | Picks the right helper for a toy patient; at levels 4-5 two steps in the right order | pretend play, sequencing; familiarises children with ordinary clinic objects (play, not medical advice) |
| Sky Flight | Pip | Steers a flying dragon up/down through a side-scrolling sky (parallax), through stars, around clouds | scrolling world + steering |
| Puffy's Day | Twinkle | Drags items onto a virtual pet to meet its need | virtual pet, drag and drop (tap also works) |
All are written, NOT compiled or played. Logged with the same event types (success, mistake, omission, response time) and the same hint ladder.

## v16: action games
| Game | Character | Mechanic | Obstacles / power-ups |
|---|---|---|---|
| Cloud Bounce | Kara | auto-bounce, steer left/right, climb | storm clouds; springs; fall = friendly bubble |
| Fruit Slice Party | Nova | swipe to slice | stinky socks; snowflake slows time |
| Dance Party | Lumi | rhythm lanes, tap on the line | grey quiet notes; combo dances |
