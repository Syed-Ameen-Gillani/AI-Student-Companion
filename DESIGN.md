# Student Companion UI direction

The interface uses calm minimalism with a compact bento-style Home summary. Students need to scan deadlines, return to notes, and start an AI conversation quickly. A warm neutral canvas, flat bordered surfaces, a restrained teal accent, and clear type hierarchy support those tasks without visual noise. Glassmorphism and neumorphism were considered, but their transparency and low-contrast edges would make dense notes, deadlines, and source excerpts harder to read.

## References reviewed

- [StudySpark on Behance](https://www.behance.net/gallery/243873199/StudySpark-Mobile-App-A-Smart-Student-Planner): clear daily planning, distinct task groupings, and fast access to study work.
- [Mirello on Behance](https://www.behance.net/gallery/220307723/Mirello-Notes-Journaling-Mobile-App-Design): restrained note surfaces and readable content hierarchy.
- [Student Productivity App on Dribbble](https://dribbble.com/shots/27294754-Student-Productivity-App-UI-Design-Focus-Planner-Study-Dash): scannable dashboard and planner layout.
- [Material 3 color roles](https://m3.material.io/styles/color/the-color-system) and [type hierarchy](https://m3.material.io/styles/typography/applying-type): semantic color pairings and a consistent text scale in light and dark themes.

The app adapts those principles to its real data and flows. It does not copy the concepts' illustrations, gamification, progress scores, or features that the app does not provide.

## Applied system

- Primary teal marks the main action, selected destination, and the Home overview. Error and secondary roles remain distinct.
- Surface and surface-container roles create separation without heavy shadows or gradients. Cards use a subtle outline and 20 px radius.
- Titles, supporting text, labels, and counts use a consistent type hierarchy. Supporting text uses the theme's on-surface variant color.
- Common spacing uses 8, 12, 16, 20, and 28 px steps; controls target at least 48 px height.
- Phones show five primary destinations in the bottom bar, with Settings in the top bar. Wider layouts use a six-destination rail.
- Empty states explain the next useful action; loading and error states retain the underlying functionality.
