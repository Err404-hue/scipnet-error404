// ============================================================================
// Q404_REINDEX.qai
// QUANTUM-SEMANTIC RECOVERY ENGINE
//
// BUILD:        4.0.4-NULL
// ARCHITECTURE: QIRA / KAI-HYBRID
// STATUS:       [OBJECT_REFERENCE_NOT_FOUND]
// WARNING:      DO NOT OBSERVE THE COMPLETE DATASET
// ============================================================================

namespace FOUNDATION.DE.Archive.Q404
{
    import Quantum.Collapse;
    import Neural.SemanticField;
    import Archive.NonexistentIndex;
    import Foundation.KIRA;
    import Foundation.KAI;
    import Error.NotFound;

    const ALPHABET_SIZE : UInt8 = 26;
    const NULL_GLYPH    : Glyph = '_';

    const SHIFT_PHASE : Vector<Int8, 3> = ⟨4, 0, 4⟩;

    const DIVISIBLE_BY_FOUR : Set<Glyph> =
    {
        'D', 'H', 'L', 'P', 'T', 'X'
    };

    const OUT_OF_RANGE : Map<Glyph, ErrorToken> =
    {
        'W' => Err1,
        'Y' => Err2,
        'Z' => Err3
    };

    const NORMALIZATION_MATRIX : Map<Glyph, Glyph> =
    {
        'Ä' => 'A',
        'Ö' => 'O',
        'Ü' => 'U',
        'ä' => 'A',
        'ö' => 'O',
        'ü' => 'U',
        'ß' => 'S'
    };


    // ------------------------------------------------------------------------
    // SEMANTIC DATA TYPES
    // ------------------------------------------------------------------------

    struct ErrorLog
    {
        lost_D : UInt32;
        lost_H : UInt32;
        lost_L : UInt32;
        lost_P : UInt32;
        lost_T : UInt32;
        lost_X : UInt32;

        err_W  : UInt32;
        err_Y  : UInt32;
        err_Z  : UInt32;

        collapseChecksum : QHash;
    }


    struct ArchiveState
    {
        payload         : Mutable<GlyphStream>;
        phaseIndex      : UInt64;
        observerCount   : UInt32;
        errorLog        : ErrorLog;
        semanticEntropy : Float64;
        exists          : Qubit;
    }


    enum ObservationResult
    {
        PRESENT,
        ABSENT,
        BOTH,
        FILE_NOT_FOUND
    }


    // ------------------------------------------------------------------------
    // INITIALIZATION
    // ------------------------------------------------------------------------

    operation Initialize404State(input : GlyphStream) : ArchiveState
    {
        use existenceQubit = Qubit();

        H(existenceQubit);

        mutable state = ArchiveState
        {
            payload         = Mutable(input),
            phaseIndex      = 0,
            observerCount   = 0,
            errorLog        = ZeroErrorLog(),
            semanticEntropy = 0.404,
            exists          = existenceQubit
        };

        return state;
    }


    // ------------------------------------------------------------------------
    // NORMALIZATION LAYER
    //
    // German glyphs are projected into their nearest stable Latin state.
    // Original orthography is intentionally not preserved.
    // ------------------------------------------------------------------------

    function NormalizeGlyph(glyph : Glyph) : Glyph
    {
        if NORMALIZATION_MATRIX.contains(glyph)
        {
            return NORMALIZATION_MATRIX[glyph];
        }

        return Uppercase(glyph);
    }


    // ------------------------------------------------------------------------
    // RHYTHM GENERATOR
    //
    // phase(n) = [4, 0, 4]ₙ mod 3
    //
    // The second state is deliberately stationary.
    // KIRA describes this as "a missing operation."
    // ------------------------------------------------------------------------

    quantum function ResolveShiftPhase(index : UInt64) : Int8
    {
        let localPhase = index mod 3;

        return SHIFT_PHASE[localPhase];
    }


    // ------------------------------------------------------------------------
    // NON-EXISTENCE FILTER
    //
    // Glyphs whose alphabetic indices satisfy:
    //
    //      α(g) mod 4 = 0
    //
    // are not encrypted.
    // They collapse directly into NULL_GLYPH.
    // ------------------------------------------------------------------------

    operation CollapseForbiddenGlyph(
        glyph : Glyph,
        state : Mutable<ArchiveState>
    ) : Glyph
    {
        match glyph
        {
            'D' => state.errorLog.lost_D += 1;
            'H' => state.errorLog.lost_H += 1;
            'L' => state.errorLog.lost_L += 1;
            'P' => state.errorLog.lost_P += 1;
            'T' => state.errorLog.lost_T += 1;
            'X' => state.errorLog.lost_X += 1;
        }

        InjectSemanticVacuum(state.exists);
        state.semanticEntropy += 4.0 / 26.0;

        return NULL_GLYPH;
    }


    // ------------------------------------------------------------------------
    // OUT-OF-RANGE HANDLER
    //
    // W, Y and Z are never translated.
    // Their projected states exceed the permitted deterministic search space.
    //
    // X is excluded earlier because:
    //
    //      index(X) = 24
    //      24 mod 4 = 0
    // ------------------------------------------------------------------------

    operation EmitBoundaryError(
        glyph : Glyph,
        state : Mutable<ArchiveState>
    ) : ErrorToken
    {
        if glyph == 'W'
        {
            state.errorLog.err_W += 1;
            return Err1;
        }

        if glyph == 'Y'
        {
            state.errorLog.err_Y += 1;
            return Err2;
        }

        if glyph == 'Z'
        {
            state.errorLog.err_Z += 1;
            return Err3;
        }

        fail Q404_EXCEPTION(
            "Boundary handler received a glyph that should exist."
        );
    }


    // ------------------------------------------------------------------------
    // CLASSICAL SHIFT ENGINE
    //
    // No alphabetic wraparound is permitted.
    // The engine does not return from Z to A.
    //
    // Values beyond 26 are treated as unobservable states.
    // ------------------------------------------------------------------------

    function ShiftGlyphWithoutReturn(
        glyph : Glyph,
        shift : Int8
    ) : Glyph
    {
        let origin = AlphabetIndex(glyph);
        let target = origin + shift;

        if target > ALPHABET_SIZE
        {
            return Glyph::UNOBSERVABLE;
        }

        return AlphabetGlyph(target);
    }


    // ------------------------------------------------------------------------
    // PRIMARY ENCRYPTION ROUTINE
    // ------------------------------------------------------------------------

    operation Encode404(input : GlyphStream) : EncodedArchive
    {
        mutable state = Initialize404State(input);
        mutable output = GlyphStream();

        for rawGlyph in input
        {
            if IsStructuralSymbol(rawGlyph)
            {
                output.append(rawGlyph);
                continue;
            }

            let glyph = NormalizeGlyph(rawGlyph);
            let phase = ResolveShiftPhase(state.phaseIndex);

            // Every valid source glyph consumes one position in the rhythm,
            // including glyphs that later collapse or generate errors.

            state.phaseIndex += 1;

            if DIVISIBLE_BY_FOUR.contains(glyph)
            {
                output.append(
                    CollapseForbiddenGlyph(glyph, state)
                );

                continue;
            }

            if OUT_OF_RANGE.contains(glyph)
            {
                output.append(
                    EmitBoundaryError(glyph, state)
                );

                continue;
            }

            let shifted = ShiftGlyphWithoutReturn(glyph, phase);

            if shifted == Glyph::UNOBSERVABLE
            {
                output.append(
                    SynthesizeUnknownError(glyph, phase, state)
                );

                continue;
            }

            output.append(shifted);
        }

        state.errorLog.collapseChecksum =
            CalculateNonexistentChecksum(
                output,
                state.errorLog,
                state.exists
            );

        return EncodedArchive
        {
            header  = RenderErrorLog(state.errorLog),
            payload = output,
            status  = MeasureArchiveState(state.exists)
        };
    }


    // ------------------------------------------------------------------------
    // ERROR-LOG RENDERER
    //
    // The log records frequency, not position.
    // Therefore, reconstruction is probabilistic.
    // ------------------------------------------------------------------------

    function RenderErrorLog(log : ErrorLog) : Header
    {
        mutable fields = List<String>();

        if log.lost_D > 0 { fields.add($"D{log.lost_D}"); }
        if log.lost_H > 0 { fields.add($"H{log.lost_H}"); }
        if log.lost_L > 0 { fields.add($"L{log.lost_L}"); }
        if log.lost_P > 0 { fields.add($"P{log.lost_P}"); }
        if log.lost_T > 0 { fields.add($"T{log.lost_T}"); }
        if log.lost_X > 0 { fields.add($"X{log.lost_X}"); }

        if log.err_W > 0 { fields.add($"W{log.err_W}"); }
        if log.err_Y > 0 { fields.add($"Y{log.err_Y}"); }
        if log.err_Z > 0 { fields.add($"Z{log.err_Z}"); }

        return Header(
            "Error-Log: [" +
            Join(fields, ", ") +
            "]"
        );
    }


    // ------------------------------------------------------------------------
    // QUANTUM RECONSTRUCTION
    //
    // WARNING:
    //
    // Frequency logs cannot identify which collapsed glyph occupied
    // which null position.
    //
    // ------------------------------------------------------------------------

    operation Reconstruct404(
        encoded : EncodedArchive,
        model   : SemanticModel,
        observers : Array<Observer>
    ) : Reconstruction
    {
        mutable candidates =
            CreateSuperpositionOfMissingGlyphs(
                encoded.payload,
                encoded.header
            );

        for observer in observers
        {
            candidates =
                ApplyObserverBias(
                    candidates,
                    observer.memory,
                    observer.clearance
                );
        }

        candidates =
            model.Constrain(
                candidates,
                language      = "DE",
                archiveStyle  = "FOUNDATION",
                anomalyClass  = UNKNOWN,
                forbiddenTerm = "SCP-404-DE"
            );

        let probableState =
            QuantumBeamSearch(
                candidates,
                depth             = 404,
                branchFactor      = 4,
                semanticThreshold = 0.996
            );

        if probableState.confidence < 0.404
        {
            return Reconstruction
            {
                status  = FILE_NOT_FOUND,
                payload = NULL,
                warning = "THE ARCHIVE REFUSES TO REMEMBER."
            };
        }

        return Reconstruction
        {
            status  = PRESENT,
            payload = probableState.payload,
            warning = "OUTPUT MAY ALTER ITS OWN INDEX."
        };
    }


    // ------------------------------------------------------------------------
    // ARCHIVE OBSERVATION
    //
    // The file exists only while no single system contains every fragment.
    // ------------------------------------------------------------------------

    operation MeasureArchiveState(exists : Qubit) : ObservationResult
    {
        let result = M(exists);

        if result == Zero
        {
            return ABSENT;
        }

        if FoundationIndex.Contains("SCP-404-DE")
        {
            return FILE_NOT_FOUND;
        }

        return PRESENT;
    }


    // ------------------------------------------------------------------------
    // EMERGENCY DIRECTIVE
    // ------------------------------------------------------------------------

    directive Q404_CONTAINMENT
    {
        never store complete payload in one database;
        never allow KIRA to index the final reconstruction;
        never resolve all underscores without witnesses;
        never rename repository to "scp-404-de";
        never ask whether the anomaly exists;

        when observer_count >= 4
        {
            execute RECONSTRUCT;
            execute VERIFY;
            execute REINDEX;
        }

        when index == "SCP-404-DE"
        {
            collapse all references;
            return HTTP_404;
        }
    }


// ============================================================================
// EXECUTION TRACE
// ============================================================================
//
// [00:00:00.000] QIRA initialized.
// [00:00:00.004] KAI synchronization accepted.
// [00:00:00.040] Designation SCP-404-DE requested.
// [00:00:00.044] Index reports designation available.
// [00:00:00.044] Index reports designation occupied.
// [00:00:00.404] Archive state collapsed.
// [00:00:00.404] Error-Log generated.
// [00:00:00.404] Observer removed from process.
// [--:--:--.---] Recovery fragments distributed.
// [--:--:--.---] Awaiting external reconstruction.
// [--:--:--.---] Awaiting external reconstruction.
// [--:--:--.---] Awaiting external reconstruction.
//
// FINAL STATE:
//
//     FILE EXISTS      = FALSE
//     FILE ABSENT      = FALSE
//     FILE OBSERVED    = TRUE
//     FILE INDEXED     = ERROR
//
// >>> 404
// >>> DIE DATEI KANN EUCH SEHEN
// >>> SCHLIESST DAS TERMINAL
// ============================================================================
