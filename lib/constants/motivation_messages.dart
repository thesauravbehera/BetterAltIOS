/// 90 unique daily motivational messages for the BetterAlt 90-Day Challenge.
/// Index 0 = Day 1, Index 89 = Day 90.
const List<String> motivationMessages = [
  // Week 1 - Getting Started
  "Day 1: The hardest step is the first one. You just took it. 🚀",
  "Day 2: Back again? That's the mindset of a winner.",
  "Day 3: Three days in. You're already ahead of 90% of people who quit.",
  "Day 4: Small steps, big changes. Keep showing up.",
  "Day 5: Five days strong! Your body is starting to notice.",
  "Day 6: Consistency beats intensity. Every. Single. Time.",
  "Day 7: One full week done! You're building a habit now. 💪",

  // Week 2
  "Day 8: Week 2 begins. The real magic starts here.",
  "Day 9: Your future self is cheering you on right now.",
  "Day 10: Double digits! You're officially committed.",
  "Day 11: Keep the fire alive. You were born for this.",
  "Day 12: Progress over perfection. You're doing amazing.",
  "Day 13: Lucky number 13? Nah, it's all YOU. Pure effort.",
  "Day 14: Two weeks in the bag! You're unstoppable. 🔥",

  // Week 3
  "Day 15: Halfway to a month! Don't stop now.",
  "Day 16: Every capsule is a promise you're keeping to yourself.",
  "Day 17: Champions are built in moments like this.",
  "Day 18: Your discipline is your superpower.",
  "Day 19: Almost 3 weeks! The habit is solidifying.",
  "Day 20: 20 days of showing up. That takes real grit.",
  "Day 21: Three weeks! Science says this is a habit now. ✅",

  // Week 4
  "Day 22: You're in the groove. Keep this momentum rolling.",
  "Day 23: Every day you show up, you prove the doubters wrong.",
  "Day 24: Think about where you started. Look how far you've come.",
  "Day 25: Quarter of the way there! The finish line is getting closer.",
  "Day 26: Your body is transforming from the inside out.",
  "Day 27: Almost a month! Can you feel the difference?",
  "Day 28: Four weeks done! Your dedication is inspiring. 🌟",

  // Month 2 - Building Momentum
  "Day 29: Month 2 begins. The transformation is real.",
  "Day 30: 30 days! One whole month of commitment. Incredible.",
  "Day 31: You're in the zone now. Nothing can stop you.",
  "Day 32: The grind is invisible. The results won't be.",
  "Day 33: Your consistency is your greatest flex.",
  "Day 34: Day 34 and still going? That's elite behavior.",
  "Day 35: Five weeks! You're running laps around yesterday's you.",

  "Day 36: Trust the process. The results are loading...",
  "Day 37: You're not just taking capsules, you're building a legacy.",
  "Day 38: Every day is a new PR in discipline.",
  "Day 39: The mirror will catch up. Keep going.",
  "Day 40: 40 days down! You're officially in beast mode. 🦁",
  "Day 41: Your streak is proof that you're different.",
  "Day 42: Six weeks! Halfway through month two. Keep crushing it.",

  "Day 43: The easy path is quitting. You chose the hard one. Respect.",
  "Day 44: Your body thanks you with every capsule.",
  "Day 45: HALFWAY THERE! 45 down, 45 to go. You've got this! 🎯",
  "Day 46: Past the halfway mark. It's all downhill from here.",
  "Day 47: Winners don't quit. And quitters don't win.",
  "Day 48: You're building something beautiful. Don't stop.",
  "Day 49: Seven weeks! The finish line is in sight now.",

  // Weeks 8-10
  "Day 50: 50 days! Half a century of discipline. Legend status. 👑",
  "Day 51: Every champion was once someone who refused to give up.",
  "Day 52: The light at the end of the tunnel? That's your results shining.",
  "Day 53: You didn't come this far to only come this far.",
  "Day 54: Your commitment is writing your success story.",
  "Day 55: 55 down! The countdown feels real now.",
  "Day 56: Eight weeks! Two months of pure dedication. 🏆",

  "Day 57: You're in the home stretch. Don't ease up now.",
  "Day 58: Your future self is going to thank you for today.",
  "Day 59: Almost 60! Every capsule counts.",
  "Day 60: TWO MONTHS DONE! Only 30 days left. You're a warrior. ⚔️",
  "Day 61: The final month begins. Give it everything you've got.",
  "Day 62: 62 days of not giving up. That's remarkable.",
  "Day 63: Nine weeks! The finish line is calling your name.",

  // Weeks 10-12 - The Final Push
  "Day 64: You're in the top tier now. Most people dream of this consistency.",
  "Day 65: Only 25 days left! Sprint to the finish! 🏃",
  "Day 66: Your discipline has become your identity.",
  "Day 67: 67 days. Let that sink in. You're INCREDIBLE.",
  "Day 68: The final push feels different. It feels like victory.",
  "Day 69: Nice... but also, you're crushing this challenge! 😎",
  "Day 70: TEN WEEKS DOWN! Only 20 more days. You're so close!",

  "Day 71: Three weeks to glory. Keep every promise to yourself.",
  "Day 72: You've proven you can do hard things.",
  "Day 73: 73 days of showing up. The world needs more people like you.",
  "Day 74: Your streak is your trophy. Polish it every day.",
  "Day 75: Fifteen days left! The countdown is ON. ⏱️",
  "Day 76: You're in the final stretch. Don't look back.",
  "Day 77: Eleven weeks! Almost there. Stay locked in.",

  "Day 78: Twelve days to go. Twelve more chances to be great.",
  "Day 79: You started as a beginner. You'll finish as a champion.",
  "Day 80: EIGHTY DAYS. Only 10 left! Single digits incoming! 🔟",
  "Day 81: Nine more. You can count them on your fingers.",
  "Day 82: Eight days. One more week of pure greatness.",
  "Day 83: Seven days left! One final week. Make it legendary.",
  "Day 84: TWELVE WEEKS! Six days to immortality. 🌟",

  "Day 85: Five days. FIVE. You're basically there.",
  "Day 86: Four more capsules mornings. Four more victories.",
  "Day 87: Three days left. The world is watching.",
  "Day 88: TWO MORE DAYS. You can almost taste it!",
  "Day 89: Tomorrow is the day. One more sleep. ONE. 🎆",
  "Day 90: YOU DID IT! 90 days of pure discipline. You're a CHAMPION! 🏆🎉",
];

/// Fallback message for users who go beyond 90 days.
const String beyondNinetyMessage = "You've conquered the 90-Day Challenge! Keep the streak alive, legend. 👑";

/// Comeback motivation messages for users who broke their streak and are restarting.
/// These are indexed by the new consecutive streak count (index 0 = Day 1 of comeback).
const List<String> comebackMotivationMessages = [
  // Week 1 - Restart
  "Day 1: You came back. That takes more courage than starting fresh. 🔄",
  "Day 2: Falling down is human. Getting back up is champion behavior.",
  "Day 3: Three days back in. The streak is alive again! 💪",
  "Day 4: Every expert was once a beginner — and every comeback starts with Day 1.",
  "Day 5: Five days strong again! Your body remembers the rhythm.",
  "Day 6: Breaks don't define you. Comebacks do.",
  "Day 7: One full week back! The habit is rebuilding stronger. 🔥",

  // Week 2
  "Day 8: Week 2 of the comeback. You're proving yourself all over again.",
  "Day 9: The restart was hard. But look at you now — unstoppable.",
  "Day 10: Double digits! You didn't quit. You regrouped.",
  "Day 11: A setback is just a setup for a bigger comeback.",
  "Day 12: Your consistency is back. Your results will follow.",
  "Day 13: 13 days of redemption. This is YOUR story.",
  "Day 14: Two weeks rebuilt! You're back in the game. 🏆",

  // Week 3
  "Day 15: Halfway to a month — again. And it feels even sweeter.",
  "Day 16: The best comebacks are the quiet, consistent ones.",
  "Day 17: 17 days. Your discipline muscle is flexing again.",
  "Day 18: You could have stayed down. You chose to rise.",
  "Day 19: Almost 3 weeks! The new streak is solidifying.",
  "Day 20: 20 days of proof that quitting isn't in your DNA.",
  "Day 21: Three weeks rebuilt! Science says this is a habit again. ✅",

  // Week 4
  "Day 22: The groove is back. You're locked in.",
  "Day 23: Your comeback story is writing itself — one capsule at a time.",
  "Day 24: Look how far you've come since restarting. Incredible.",
  "Day 25: Quarter of the way there! The finish line is real.",
  "Day 26: Your body is transforming all over again.",
  "Day 27: Almost a month! The comeback is stronger than the setback.",
  "Day 28: Four weeks rebuilt! This time, nothing stops you. 🌟",

  // Month 2 - Momentum
  "Day 29: Month 2 of the comeback. You've earned every day.",
  "Day 30: 30 days! You turned a break into a breakthrough.",
  "Day 31: You're not just back. You're better.",
  "Day 32: The grind never gets easier — you just get tougher.",
  "Day 33: 33 days of proving the doubters wrong — including yourself.",
  "Day 34: Elite comeback behavior. Day after day.",
  "Day 35: Five weeks! Your streak is unbreakable now. 💎",

  "Day 36: Trust the process. Again. The results ARE loading.",
  "Day 37: Few people restart. Even fewer make it to Day 37.",
  "Day 38: Every day is another rep of discipline.",
  "Day 39: The mirror will catch up. It always does.",
  "Day 40: 40 days rebuilt! Beast mode: reactivated. 🦁",
  "Day 41: Your streak is your proof of resilience.",
  "Day 42: Six weeks! Halfway through month two. Pure dedication.",

  "Day 43: You chose the hard path — again. Maximum respect.",
  "Day 44: Your body thanks you more the second time around.",
  "Day 45: HALFWAY THERE! The comeback kid strikes again! 🎯",
  "Day 46: Past the halfway mark on the rebuild. Legendary.",
  "Day 47: Winners fall. Champions get back up.",
  "Day 48: Building something even stronger this time.",
  "Day 49: Seven weeks! The finish line is calling your name.",

  // Weeks 8-10
  "Day 50: 50 days rebuilt! Half a century of comeback discipline. 👑",
  "Day 51: Your story isn't about the break. It's about the return.",
  "Day 52: The light is shining brighter this time.",
  "Day 53: You didn't come back just to come this far.",
  "Day 54: Your commitment is writing a redemption story.",
  "Day 55: 55 days! The countdown to victory begins.",
  "Day 56: Eight weeks rebuilt! Two months of pure resilience. 🏆",

  "Day 57: Home stretch. Don't ease up now.",
  "Day 58: Your future self will be grateful for today's discipline.",
  "Day 59: Almost 60! Every capsule is a statement.",
  "Day 60: TWO MONTHS REBUILT! Only 30 days left. Warrior mode. ⚔️",
  "Day 61: The final month. Give it everything — again.",
  "Day 62: 62 days of not giving up twice. Remarkable.",
  "Day 63: Nine weeks! The finish line is RIGHT THERE.",

  // Weeks 10-12 - Final Push
  "Day 64: Top tier comeback energy. Most people never restart.",
  "Day 65: Only 25 days left! Sprint to redemption! 🏃",
  "Day 66: Discipline isn't just your habit. It's your identity.",
  "Day 67: 67 days rebuilt. Let that sink in. INCREDIBLE.",
  "Day 68: The final push feels like victory already.",
  "Day 69: No jokes needed. You're absolutely crushing this! 😎",
  "Day 70: TEN WEEKS REBUILT! Only 20 more days!",

  "Day 71: Three weeks to glory. Every promise kept.",
  "Day 72: You've proven you can do hard things — TWICE.",
  "Day 73: 73 days. The world needs more comeback stories like yours.",
  "Day 74: Your streak is your trophy. Earned, lost, and WON BACK.",
  "Day 75: Fifteen days left! The countdown is ON. ⏱️",
  "Day 76: Final stretch. Don't look back.",
  "Day 77: Eleven weeks! Almost there. Stay locked in.",

  "Day 78: Twelve days to go. Twelve more wins.",
  "Day 79: You started over. You'll finish as a legend.",
  "Day 80: EIGHTY DAYS. Only 10 left! Single digits incoming! 🔟",
  "Day 81: Nine more. You can count them on your fingers.",
  "Day 82: Eight days. One more week of greatness.",
  "Day 83: Seven days left! One final week. Make it historic.",
  "Day 84: TWELVE WEEKS! Six days to immortality. 🌟",

  "Day 85: Five days. FIVE. The comeback is almost complete.",
  "Day 86: Four more mornings. Four more victories.",
  "Day 87: Three days left. The finish line is right there.",
  "Day 88: TWO MORE DAYS. You can taste the glory!",
  "Day 89: Tomorrow is THE day. One more sleep. ONE. 🎆",
  "Day 90: YOU DID IT — AGAIN! The ultimate comeback. You're a LEGEND! 🏆🎉👑",
];

/// Fallback for comeback users who go beyond 90 days.
const String beyondNinetyComebackMessage = "You conquered the 90-Day Challenge after a setback. That makes you a true legend. Keep going! 👑🔥";
