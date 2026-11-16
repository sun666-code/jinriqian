import Foundation

// MARK: - 签库英文（内置 24 支）。自定义签库可在 lots.json 里加 nameEn / noteEn 等字段。

extension LotLibrary {
    struct EnText {
        let name: String
        let poem: String
        let note: String
        let todo: [String]
        let avoid: [String]
        let one: String
    }

    static var custom: [Int: EnText] = [:]
    static var english: [Int: EnText] { custom.isEmpty ? builtinEn.merging(hexEn) { a, _ in a } : custom }

    static let levelEn: [String: String] = ["上上": "Supreme", "上吉": "Great", "中吉": "Good", "中平": "Steady", "守成": "Hold", "静养": "Rest"]

    static let builtinEn: [Int: EnText] = [
        1: EnText(name: "Dawn", poem: "The first branch blooms as the snow melts away.", note: "Something you've been mulling over is ready for a first small step. A good start is half the win.",
                  todo: ["Start a new plan", "Reach out to an old friend", "Get ten minutes of sun"], avoid: ["Shelving a good idea again", "Saying yes to everything", "Late-night celebrating"], one: "Write the thing you want to do in one line and stick it by your screen."),
        2: EnText(name: "Moonrise", poem: "Open the window: the moon is right above, let old things drift.", note: "What's been weighing on you loosens a little today. Go with the flow.",
                  todo: ["Say an overdue thank-you", "Wrap up an old task", "Archive old files"], avoid: ["Arguing to win", "Digging up the past", "Scrolling in bed"], one: "Send someone you haven't talked to in a while a quick \"how are you?\""),
        3: EnText(name: "By the Brook", poem: "Crossing the bridge by the stream, a stranger shares the ladle.", note: "People are willing to help today. Asking is easier than carrying it alone.",
                  todo: ["Ask a colleague one question", "Have lunch with someone", "Drink warm water"], avoid: ["Shouldering everything", "Jumping to conclusions", "Skipping lunch"], one: "Ask one question today, even if it seems simple."),
        4: EnText(name: "Pine Wind", poem: "No rush beneath the pines; tea waits for the sky to clear.", note: "Good things are on their way, just slowly. A steady pace beats speeding up.",
                  todo: ["Do something that takes patience", "Brew a pot of tea", "Read twenty pages"], avoid: ["Chasing replies", "Refreshing progress", "Texting while walking"], one: "Turn off notifications for 25 minutes and finish one thing."),
        5: EnText(name: "Swallows Return", poem: "The swallow knows its old eave; a home is built beak by beak.", note: "Life is built bit by bit. Tidy the small things around you today.",
                  todo: ["Clear one corner of the room", "Call home", "Cook a meal yourself"], avoid: ["Dismissing small progress", "Big spending", "Takeout again"], one: "Empty one drawer, or toss three things you never use."),
        6: EnText(name: "Planting Bamboo", poem: "Plant a few stalks today; shade will fill the yard one day.", note: "Today's effort won't pay off right away, but future you will be grateful.",
                  todo: ["Learn something new", "Save a little money", "Water the plants"], avoid: ["Expecting instant results", "Comparing progress", "Overworking"], one: "Spend 10 minutes learning something and jot down one takeaway."),
        7: EnText(name: "Sailing", poem: "Don't rush downstream; the green hills will come in time.", note: "Things are moving along fine. Keep your current pace — that's the best move today.",
                  todo: ["Follow the plan", "Leave a bit early", "Do a quick review"], avoid: ["Piling on extra work", "Taking shortcuts", "Doing too much at once"], one: "Leave 10 minutes early and enjoy the view on the way."),
        8: EnText(name: "Rain Listening", poem: "Night rain on the window — tomorrow brings fresh streams.", note: "A little mood is normal; it passes like rain. Look after yourself first.",
                  todo: ["Play an album you love", "Finish work early", "Soak your feet before bed"], avoid: ["Replying while upset", "Big decisions", "Late-night self-doubt"], one: "Write down one thing that bothered you today, then close the notebook."),
        9: EnText(name: "Half Cloud", poem: "Clouds hide the ridge, yet the path under your feet is clear.", note: "You can't see far, and that's fine. The next step is clear — just take it.",
                  todo: ["Make a short list", "Finish the smallest item", "Sleep half an hour earlier"], avoid: ["Planning too far ahead", "Going in circles", "Deciding on an empty stomach"], one: "Write down only the single most important thing for tomorrow."),
        10: EnText(name: "Frosty Bridge", poem: "Slow steps on a frosty bridge; look back and smile at dawn.", note: "Small slip-ups are likely today; slowing down avoids them. It's a nudge, not bad luck.",
                   todo: ["Double-check before sending", "Wear comfortable shoes", "Back up important files"], avoid: ["Signing or paying in a hurry", "Phone while crossing", "Replying angry"], one: "Write the important message, wait 10 minutes, then send."),
        11: EnText(name: "Half Sail", poem: "Against the wind, lower half the sail and wait for fair skies.", note: "Pushing forward may feel hard today. Ease off and hold your ground.",
                   todo: ["Make the safer choice", "Have a hot soup", "Rest early"], avoid: ["Winning every argument", "All-or-nothing bets", "Big purchases"], one: "Hold back one rebuttal today and see what happens."),
        12: EnText(name: "Quiet Night", poem: "Dim the lamp, close the book — long nights restore the spirit.", note: "Not a bad day — a resting day. Fewer decisions, earlier sleep, and tomorrow flows better.",
                   todo: ["Head home early", "Eat a proper meal", "Sort out your feelings"], avoid: ["Staying up late", "Negotiations or showdowns", "Catastrophizing"], one: "Put the phone down before 11 tonight for a full night's sleep."),
        13: EnText(name: "Open Window", poem: "An east wind overnight; open the window to fresh green.", note: "A new angle makes things simple. Try new methods and meet new people.",
                   todo: ["Take a new route to work", "Try a new tool", "Meet someone new"], avoid: ["Clinging to old ways", "Dismissing new ideas", "Staying in all day"], one: "Do one small thing you've never done before."),
        14: EnText(name: "Crane Call", poem: "The crane's call carries far without climbing higher.", note: "People notice your work. Just do it well — no need to prove yourself.",
                   todo: ["Polish your work", "Review what you've achieved", "Give yourself credit"], avoid: ["Over-explaining", "Interrupting", "Competing for volume"], one: "Describe one thing you finished this week in three sentences."),
        15: EnText(name: "Spring Soil", poem: "Fallen petals warm the soil and shelter new sprouts.", note: "Nothing you've been through is wasted. Care for others — and for yourself.",
                   todo: ["Do someone a small favor", "Tidy old notes", "Eat some fresh fruit"], avoid: ["Judging your past self", "Hating slowness", "Skipping breakfast"], one: "Reread one page of old notes and find a line that still helps."),
        16: EnText(name: "Far Hills", poem: "Distant hills stay green; step by step the road goes on.", note: "The goal is far, but the direction is right. Move forward one notch today.",
                   todo: ["Advance a long project a bit", "Walk for twenty minutes", "Update your plan"], avoid: ["Short-lived enthusiasm", "Not starting because it's far", "Going too fast"], one: "Set a small step toward a long goal that you can finish this week."),
        17: EnText(name: "Clear River", poem: "A clear river, good for sailing; things come as they will.", note: "Things flow today. Clear up that pending conversation — gently.",
                   todo: ["Say what needs saying", "Settle an open question", "Go for a walk"], avoid: ["Being vague", "Giving the silent treatment", "Last-minute cancelling"], one: "Reply to the message you've been putting off."),
        18: EnText(name: "Lamplight", poem: "Grinding ink by the lamp — don't fret over an unfinished stroke.", note: "It may take a few tries today. Not smooth doesn't mean wrong.",
                   todo: ["Practice a skill", "Clear your desk", "Note today's progress"], avoid: ["Quitting after one try", "Phone while working", "Being hard on yourself"], one: "Turn today's sticking point into a question and look at it tomorrow."),
        19: EnText(name: "Fireflies", poem: "A firefly's small light doesn't compete with the moon.", note: "Small efforts shine too. No big things needed — do small things well.",
                   todo: ["Finish three small tasks", "Compliment someone", "Walk after dinner"], avoid: ["Underrating small wins", "Comparing", "Dragging into the night"], one: "Before bed, write down three small things you finished."),
        20: EnText(name: "Still Clouds", poem: "Sit with the still clouds; raise your cup when the wind comes.", note: "The timing isn't right yet. Prepare, organize and wait.",
                   todo: ["Gather your materials", "Sort your to-do list", "Eat on time"], avoid: ["Rushing a decision", "Forcing progress", "Coffee on an empty stomach"], one: "List the three things still missing for this to happen."),
        21: EnText(name: "White Dew", poem: "When dew turns white, an extra layer warms the heart.", note: "Your body is asking you to slow down. Put self-care first today.",
                   todo: ["Add a layer", "Drink something warm", "Go to bed early"], avoid: ["Pushing through overtime", "Too much cold food", "Binge-watching late"], one: "Give yourself 30 minutes of doing nothing at all."),
        22: EnText(name: "Geese Return", poem: "When the geese return and the moon fills the tower, worries rest.", note: "The news you've been waiting for may arrive today. Stay open.",
                   todo: ["Check your mail and messages", "Contact family", "Prepare a small treat"], avoid: ["Worrying about outcomes", "Checking over and over", "Bottling things up"], one: "Call someone who cares about you."),
        23: EnText(name: "Bamboo Shadow", poem: "Bamboo shadows sweep the steps, yet no dust stirs.", note: "However busy outside, you can be calm inside. Focus and avoid interruptions.",
                   todo: ["Block out focus time", "Clean up a folder", "Breathe deeply for a few minutes"], avoid: ["Constant task switching", "Being led by notifications", "Ad-hoc meetings"], one: "Set a 45-minute do-not-disturb block."),
        24: EnText(name: "First Snow", poem: "First snow covers the path; tomorrow the footprints will be clear.", note: "Things will become clear over time. Judge less, observe more today.",
                   todo: ["Listen more, talk less", "Note one observation", "Tidy your closet"], avoid: ["Rushing to conclusions", "Spreading unverified news", "Impulse buying"], one: "Write down one small thing that surprised you today."),
    ]
}
