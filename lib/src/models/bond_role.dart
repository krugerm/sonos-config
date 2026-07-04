/// How a device currently sits in the topology.
///
/// [standalone] = not bonded (a lone speaker, visible or an unbonded Sub).
/// [coordinator] = a room's primary that has bonded satellites.
/// The remaining roles describe a currently-bonded satellite's channel.
enum BondRole {
  standalone,
  coordinator,
  sub,
  surroundLeft,
  surroundRight,
  stereoLeft,
  stereoRight,
}
