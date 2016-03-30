(**
 * @copyright (c) 2011, Tohoku University.
 * @author UENO Katsuhiro
 *)
structure TypeLayout2 : sig

  val runtimeTy : Types.btvEnv
                  -> Types.ty
                  -> RuntimeTypes.ty option
  val tagOf : RuntimeTypes.ty -> RuntimeTypes.tag
  val tagValue : RuntimeTypes.tag -> int

  datatype size_assumption =
      ALL_SIZES_ARE_POWER_OF_2
  datatype align_computation =
      ALIGN_EQUAL_SIZE

  val sizeOf : RuntimeTypes.ty -> int
  val maxSize : int
  val sizeAssumption : size_assumption
  val alignComputation : align_computation
  val charBits : int

  val init : LLVMUtils.compile_options -> unit

end =
struct

  structure T = Types
  structure R = RuntimeTypes

  val emptyBtvEnv = BoundTypeVarID.Map.empty : T.btvEnv

  fun runtimeTyTvarKind tvarKind =
      case tvarKind of
        T.UNIV => NONE
      | T.BOXED => SOME R.BOXEDty
      | T.UNBOXED => NONE
      | T.OPRIMkind _ => NONE
      | T.OCONSTkind _ => NONE
      | T.REC _ => SOME R.BOXEDty
      | T.JOIN _ => SOME R.BOXEDty

  fun runtimeTy btvEnv ty =
      case ty of
        T.SINGLETONty (T.INSTCODEty _) => SOME R.BOXEDty
      | T.SINGLETONty (T.INDEXty _) => SOME R.UINT32ty
      | T.SINGLETONty (T.TAGty _) => SOME R.UINT32ty
      | T.SINGLETONty (T.SIZEty _) => SOME R.UINT32ty
      | T.BACKENDty (T.RECORDSIZEty _) => SOME R.UINT32ty
      | T.BACKENDty (T.RECORDBITMAPINDEXty _) => SOME R.UINT32ty
      | T.BACKENDty (T.RECORDBITMAPty _) => SOME R.UINT32ty
      | T.BACKENDty (T.CCONVTAGty _) => SOME R.UINT32ty
      | T.BACKENDty T.SOME_CLOSUREENVty => SOME R.BOXEDty
      | T.BACKENDty T.SOME_CCONVTAGty => SOME R.UINT32ty
      | T.BACKENDty T.SOME_FUNENTRYty => SOME R.SOME_CODEPTRty
      | T.BACKENDty T.SOME_FUNWRAPPERty => SOME R.SOME_CODEPTRty
      | T.BACKENDty (T.FUNENTRYty {tyvars, haveClsEnv, argTyList, retTy}) =>
        SOME (R.MLCODEPTRty
                {haveClsEnv = haveClsEnv,
                 argTys = map (runtimeArgTy tyvars) argTyList,
                 retTy = Option.map (runtimeArgTy tyvars) retTy})
      | T.BACKENDty (T.CALLBACKENTRYty ({tyvars, haveClsEnv, argTyList, retTy,
                                         attributes})) =>
        SOME (R.CALLBACKCODEPTRty
                {haveClsEnv = haveClsEnv,
                 argTys = map (runtimeArgTy tyvars) argTyList,
                 retTy = Option.map (runtimeArgTy tyvars) retTy,
                 attributes = attributes})
      | T.BACKENDty (T.FOREIGNFUNPTRty {tyvars, argTyList, varArgTyList,
                                        resultTy, attributes}) =>
        SOME (R.FOREIGNCODEPTRty
                {argTys = map (runtimeArgTy tyvars) argTyList,
                 varArgTys =
                   Option.map (map (runtimeArgTy tyvars)) varArgTyList,
                 retTy = Option.map (runtimeArgTy tyvars) resultTy,
                 attributes = attributes})
      | T.ERRORty => NONE
      | T.DUMMYty _ => SOME R.INT32ty
      | T.TYVARty (ref (T.TVAR {tvarKind,...})) => runtimeTyTvarKind tvarKind
      | T.TYVARty (ref (T.SUBSTITUTED ty)) => runtimeTy btvEnv ty
      | T.FUNMty _ => SOME R.BOXEDty  (* function closure *)
      | T.RECORDty _ => SOME R.BOXEDty
      | T.POLYty {boundtvars, body} =>
        runtimeTy (BoundTypeVarID.Map.unionWith #2 (btvEnv, boundtvars)) body
      | T.CONSTRUCTty {tyCon, args} =>
        (
          case #dtyKind tyCon of
            T.BUILTIN ty => SOME (BuiltinTypeNames.runtimeTy ty)
          | T.OPAQUE {opaqueRep, revealKey} =>
            (
              case opaqueRep of
                T.TYCON tyCon =>
                runtimeTy btvEnv (T.CONSTRUCTty {tyCon=tyCon, args=args})
              | T.TFUNDEF {iseq, arity, polyTy} =>
                runtimeTy btvEnv (TypesBasics.tpappTy (polyTy, args))
            )
          | T.DTY =>
            SOME (BuiltinTypeNames.runtimeTy (#runtimeTy tyCon))
        )
      | T.BOUNDVARty tid =>
        case BoundTypeVarID.Map.find (btvEnv, tid) of
          SOME {tvarKind,...} => runtimeTyTvarKind tvarKind
        | NONE => NONE

  and runtimeArgTy btvEnv ty =
      case TypesBasics.derefTy ty of
        T.BOUNDVARty tid =>
        (case BoundTypeVarID.Map.find (btvEnv, tid) of
           SOME {tvarKind,...} =>
           (case runtimeTyTvarKind tvarKind of
              SOME ty => ty
            | NONE => R.BOXEDty)
         | NONE => raise Bug.Bug "runtimeArgTy: BOUNDVARty")
      | _ =>
        case runtimeTy btvEnv ty of
          SOME ty => ty
        | NONE => raise Bug.Bug "runtimeArgTy"

  fun tagOf ty =
      case ty of
        R.UNITty => R.TAG_UNBOXED
      | R.UINT8ty => R.TAG_UNBOXED
      | R.INT32ty => R.TAG_UNBOXED
      | R.INT64ty => R.TAG_UNBOXED
      | R.UINT32ty => R.TAG_UNBOXED
      | R.UINT64ty => R.TAG_UNBOXED
      | R.DOUBLEty => R.TAG_UNBOXED
      | R.FLOATty => R.TAG_UNBOXED
      | R.BOXEDty => R.TAG_BOXED
      | R.POINTERty => R.TAG_UNBOXED
      | R.SOME_CODEPTRty => R.TAG_UNBOXED
      | R.MLCODEPTRty _ => R.TAG_UNBOXED
      | R.FOREIGNCODEPTRty _ => R.TAG_UNBOXED
      | R.CALLBACKCODEPTRty _ => R.TAG_UNBOXED

  fun tagValue R.TAG_UNBOXED = 0
    | tagValue R.TAG_BOXED = 1

  datatype size_assumption =
      (* every type has power-of-2 size *)
      ALL_SIZES_ARE_POWER_OF_2
(*
    | (* every type except long double has power-of-2 size *)
      ALL_SIZES_ARE_POWER_OF_2_EXCEPT_LONG_DOUBLE
*)
  datatype align_computation =
      (* For every type, its alignment is equal to its size *)
      ALIGN_EQUAL_SIZE
(*
    | (* For every type except double, its alignment is equal to its size.
       * The size of double is 8 and its alignment is 4. *)
      ALIGN_EQUAL_SIZE_EXECPT_DOUBLE
    | (* For each type whose size is larger than 8, its alignment is 4.
       * For any other types, their alignments are equal to their sizes *)
      ALIGN_UPTO_4
*)

  val pointerSize = ref 0

  fun init ({triple, arch, cpu, features, ...}:LLVMUtils.compile_options) =
      let
        val t = LLVM.LLVMGetTargetFromArchAndTriple (arch, triple)
        val tm = LLVM.LLVMCreateTargetMachine
                   (t, triple, cpu, features, LLVM.OptDefault,
                    LLVM.RelocDefault, LLVM.CodeModelDefault)
        val tmd = LLVM.LLVMGetTargetMachineData tm
      in
        pointerSize := Word.toInt (LLVM.LLVMPointerSize tmd);
        LLVM.LLVMDisposeTargetMachine tm
      end

  (* FIXME: ILP32 layout is hard-coded. *)

  fun sizeOf ty =
      case ty of
        R.UNITty => !pointerSize
      | R.UINT8ty => 1
      | R.INT32ty => 4
      | R.INT64ty => 8
      | R.UINT32ty => 4
      | R.UINT64ty => 8
      | R.DOUBLEty => 8
      | R.FLOATty => 4
      | R.BOXEDty => !pointerSize
      | R.POINTERty => !pointerSize
      | R.MLCODEPTRty _ => !pointerSize
      | R.SOME_CODEPTRty => !pointerSize
      | R.FOREIGNCODEPTRty _ => !pointerSize
      | R.CALLBACKCODEPTRty _ => !pointerSize

  val charBits = 8

  (* maximum size that sizeOf returns.
   * It is also the maximum alignment constraint *)
  val maxSize = 8

  (* NOTE: On x86 Linux (and any other long-lived operating systems on x86),
   * sizeof(long double) is 12. So ALL_SIZES_ARE_POWER_OF_2_EXCEPT_LONG_DOUBLE
   * is more appropriate for those platforms. *)
  val sizeAssumption = ALL_SIZES_ARE_POWER_OF_2
  val alignComputation = ALIGN_EQUAL_SIZE
end
