(**
 * 
 * @author YAMATODANI Kiyoshi
 * @version $Id: Real32.sml,v 1.2 2007/11/05 02:01:30 kiyoshiy Exp $
 *)
structure Real32 =
struct
  open Real32

  (* ToDo : implement structure members.
   * It is better to define a functor RealBase to share code with Real64
   *)

  infix ==
  fun x == y = (not ((x : Real32.real) < y)) andalso (not (y < x))
  val toString = SMLSharp.Runtime.Float_toString

end;