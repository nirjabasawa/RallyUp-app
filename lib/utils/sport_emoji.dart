/// Sport → emoji lookup used by court / booking cards.
///
/// Pulled into its own file so the Courts tab, Court Details page,
/// Book Court overlay, BookingConfirmedPage, MyBookingsPage, and the
/// home previews all draw from the same table — otherwise we'd be
/// duplicating the same switch in five places (which is exactly what
/// the static-mock data did, and the reason the mocks ended up
/// inconsistent).
///
/// Pickleball: there is no dedicated Unicode emoji for pickleball.
/// The previous table reused 🎾 here, which made Cupertino Sports
/// Center (Tennis + Badminton + Pickleball) read as three tennis
/// rows. We use a green circle 🟢 instead — neutral, distinct, and
/// what the spec called for as "use simple text or 🟢 if no better
/// icon, but do not reuse tennis in a confusing way".
String sportEmojiFor(String sport) {
  switch (sport) {
    case 'Tennis':
      return '🎾';
    case 'Badminton':
      return '🏸';
    case 'Table Tennis':
      return '🏓';
    case 'Basketball':
      return '🏀';
    case 'Volleyball':
      return '🏐';
    case 'Pickleball':
      return '🟢';
    case 'Soccer':
      return '⚽';
    case 'Football':
      return '🏈';
    case 'Cricket':
      return '🏏';
    case 'Swimming':
      return '🏊';
    default:
      return '🏟️';
  }
}
