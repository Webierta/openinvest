import 'package:flutter_test/flutter_test.dart';

import 'package:investing/services/isin_resolver.dart';

void main() {
  group('LF-17 - IsinResolution', () {
    // -----------------------------------------------------------------------
    // Datos de prueba
    // -----------------------------------------------------------------------

    const candidateAFromCnmv = IsinResult(
      isin: 'ES0000000001',
      source: 'CNMV',
      officialName: 'Fondo A CNMV',
      cnmvRegistration: 1001,
      cnmvNif: 'V00000001',
    );

    const candidateAFromFondos = IsinResult(
      isin: 'ES0000000001',
      source: 'fondos.json',
      officialName: 'Fondo A fondos.json',
    );

    const candidateAFromEcb = IsinResult(
      isin: 'ES0000000001',
      source: 'ECB',
      officialName: 'Fondo A ECB',
    );

    const candidateBFromFondos = IsinResult(
      isin: 'ES0000000002',
      source: 'fondos.json',
      officialName: 'Fondo B',
    );

    const candidateBFromEcb = IsinResult(
      isin: 'ES0000000002',
      source: 'ECB',
      officialName: 'Fondo B ECB',
    );

    const candidateCFromEcb = IsinResult(
      isin: 'ES0000000003',
      source: 'ECB',
      officialName: 'Fondo C',
    );

    // -----------------------------------------------------------------------
    // LF-17.1 - Modelo de resolución
    // -----------------------------------------------------------------------

    group('LF-17.1 - modelo de resolución', () {
      test('LF-17.1.1 - una resolución vacía contiene cero candidatos', () {
        const resolution = IsinResolution(candidates: <IsinCandidate>[]);

        expect(resolution.candidates, isEmpty);
      });

      test('LF-17.1.2 - una resolución puede contener un único candidato', () {
        const resolution = IsinResolution(
          candidates: <IsinCandidate>[
            IsinCandidate(
              isin: 'ES0000000001',
              evidence: <IsinResult>[candidateAFromCnmv],
            ),
          ],
        );

        expect(resolution.candidates, hasLength(1));
        expect(resolution.candidates.single.isin, 'ES0000000001');
      });

      test('LF-17.1.3 - una resolución puede contener varios candidatos', () {
        const resolution = IsinResolution(
          candidates: <IsinCandidate>[
            IsinCandidate(
              isin: 'ES0000000001',
              evidence: <IsinResult>[candidateAFromCnmv],
            ),
            IsinCandidate(
              isin: 'ES0000000002',
              evidence: <IsinResult>[candidateBFromFondos],
            ),
            IsinCandidate(
              isin: 'ES0000000003',
              evidence: <IsinResult>[candidateCFromEcb],
            ),
          ],
        );

        expect(resolution.candidates, hasLength(3));
      });

      test('LF-17.1.4 - un candidato conserva todas sus evidencias', () {
        const resolution = IsinResolution(
          candidates: <IsinCandidate>[
            IsinCandidate(
              isin: 'ES0000000001',
              evidence: <IsinResult>[
                candidateAFromCnmv,
                candidateAFromFondos,
                candidateAFromEcb,
              ],
            ),
          ],
        );

        final candidate = resolution.candidates.single;

        expect(candidate.isin, 'ES0000000001');
        expect(candidate.evidence, hasLength(3));

        expect(
          candidate.evidence.map((e) => e.source),
          containsAll(<String>['CNMV', 'fondos.json', 'ECB']),
        );
      });

      test('LF-17.1.5 - cada evidencia conserva sus propios metadatos', () {
        const resolution = IsinResolution(
          candidates: <IsinCandidate>[
            IsinCandidate(
              isin: 'ES0000000001',
              evidence: <IsinResult>[candidateAFromCnmv, candidateAFromFondos],
            ),
          ],
        );

        final evidence = resolution.candidates.single.evidence;

        final cnmv = evidence.firstWhere((result) => result.source == 'CNMV');

        final fondos = evidence.firstWhere(
          (result) => result.source == 'fondos.json',
        );

        expect(cnmv.officialName, 'Fondo A CNMV');
        expect(cnmv.cnmvRegistration, 1001);
        expect(cnmv.cnmvNif, 'V00000001');

        expect(fondos.officialName, 'Fondo A fondos.json');
        expect(fondos.cnmvRegistration, isNull);
        expect(fondos.cnmvNif, isNull);
      });

      test('LF-17.1.6 - candidatos con ISIN diferentes pueden coexistir', () {
        const resolution = IsinResolution(
          candidates: <IsinCandidate>[
            IsinCandidate(
              isin: 'ES0000000001',
              evidence: <IsinResult>[candidateAFromCnmv],
            ),
            IsinCandidate(
              isin: 'ES0000000002',
              evidence: <IsinResult>[candidateBFromFondos],
            ),
          ],
        );

        expect(
          resolution.candidates.map((candidate) => candidate.isin),
          containsAll(<String>['ES0000000001', 'ES0000000002']),
        );
      });
    });

    // -----------------------------------------------------------------------
    // LF-17.2 - Resolución 0 / 1 / N
    // -----------------------------------------------------------------------

    group('LF-17.2 - resolución 0/1/N', () {
      test('LF-17.2.1 - nombre desconocido produce cero candidatos', () {
        const resolution = IsinResolution(candidates: <IsinCandidate>[]);

        expect(resolution.candidates, isEmpty);
      });

      test('LF-17.2.2 - nombre con un único ISIN produce un candidato', () {
        const resolution = IsinResolution(
          candidates: <IsinCandidate>[
            IsinCandidate(
              isin: 'ES0000000001',
              evidence: <IsinResult>[candidateAFromCnmv],
            ),
          ],
        );

        expect(resolution.candidates, hasLength(1));
        expect(resolution.candidates.single.isin, 'ES0000000001');
      });

      test('LF-17.2.3 - nombre con dos ISIN conserva ambos', () {
        const resolution = IsinResolution(
          candidates: <IsinCandidate>[
            IsinCandidate(
              isin: 'ES0000000001',
              evidence: <IsinResult>[candidateAFromCnmv],
            ),
            IsinCandidate(
              isin: 'ES0000000002',
              evidence: <IsinResult>[candidateBFromFondos],
            ),
          ],
        );

        expect(
          resolution.candidates.map((candidate) => candidate.isin).toSet(),
          <String>{'ES0000000001', 'ES0000000002'},
        );
      });

      test('LF-17.2.4 - nombre con tres ISIN conserva los tres', () {
        const resolution = IsinResolution(
          candidates: <IsinCandidate>[
            IsinCandidate(
              isin: 'ES0000000001',
              evidence: <IsinResult>[candidateAFromCnmv],
            ),
            IsinCandidate(
              isin: 'ES0000000002',
              evidence: <IsinResult>[candidateBFromFondos],
            ),
            IsinCandidate(
              isin: 'ES0000000003',
              evidence: <IsinResult>[candidateCFromEcb],
            ),
          ],
        );

        expect(
          resolution.candidates.map((candidate) => candidate.isin).toSet(),
          <String>{'ES0000000001', 'ES0000000002', 'ES0000000003'},
        );
      });

      test('LF-17.2.5 - múltiples ISIN no deben resolverse eligiendo uno', () {
        const resolution = IsinResolution(
          candidates: <IsinCandidate>[
            IsinCandidate(
              isin: 'ES0000000001',
              evidence: <IsinResult>[candidateAFromCnmv],
            ),
            IsinCandidate(
              isin: 'ES0000000002',
              evidence: <IsinResult>[candidateBFromFondos],
            ),
          ],
        );

        expect(resolution.candidates, hasLength(2));

        expect(
          resolution.candidates.map((candidate) => candidate.isin),
          containsAll(<String>['ES0000000001', 'ES0000000002']),
        );
      });

      test('LF-17.2.6 - todos los candidatos están disponibles para la UI', () {
        const resolution = IsinResolution(
          candidates: <IsinCandidate>[
            IsinCandidate(
              isin: 'ES0000000001',
              evidence: <IsinResult>[candidateAFromCnmv],
            ),
            IsinCandidate(
              isin: 'ES0000000002',
              evidence: <IsinResult>[candidateBFromFondos],
            ),
            IsinCandidate(
              isin: 'ES0000000003',
              evidence: <IsinResult>[candidateCFromEcb],
            ),
          ],
        );

        final isins = resolution.candidates
            .map((candidate) => candidate.isin)
            .toList();

        expect(isins, hasLength(3));
        expect(isins, contains('ES0000000001'));
        expect(isins, contains('ES0000000002'));
        expect(isins, contains('ES0000000003'));
      });
    });

    // -----------------------------------------------------------------------
    // LF-17.3 - Agregación y deduplicación entre fuentes
    // -----------------------------------------------------------------------

    group('LF-17.3 - agregación entre fuentes', () {
      test('LF-17.3.1 - el mismo ISIN procedente de dos fuentes '
          'forma un solo candidato', () {
        final resolution = IsinResolution.fromSourceResults(<List<IsinResult>>[
          <IsinResult>[candidateAFromCnmv],
          <IsinResult>[candidateAFromFondos],
        ]);

        expect(resolution.candidates, hasLength(1));
        expect(resolution.candidates.single.isin, 'ES0000000001');
      });

      test('LF-17.3.2 - CNMV A + fondos.json A produce un único A '
          'con dos evidencias', () {
        final resolution = IsinResolution.fromSourceResults(<List<IsinResult>>[
          <IsinResult>[candidateAFromCnmv],
          <IsinResult>[candidateAFromFondos],
        ]);

        final candidate = resolution.candidates.single;

        expect(candidate.isin, 'ES0000000001');
        expect(candidate.evidence, hasLength(2));

        expect(
          candidate.evidence.map((e) => e.source),
          containsAll(<String>['CNMV', 'fondos.json']),
        );
      });

      test('LF-17.3.3 - CNMV A + fondos.json A,B produce A y B', () {
        final resolution = IsinResolution.fromSourceResults(<List<IsinResult>>[
          <IsinResult>[candidateAFromCnmv],
          <IsinResult>[candidateAFromFondos, candidateBFromFondos],
        ]);

        expect(
          resolution.candidates.map((candidate) => candidate.isin).toSet(),
          <String>{'ES0000000001', 'ES0000000002'},
        );

        final candidateA = resolution.candidates.firstWhere(
          (candidate) => candidate.isin == 'ES0000000001',
        );

        final candidateB = resolution.candidates.firstWhere(
          (candidate) => candidate.isin == 'ES0000000002',
        );

        expect(candidateA.evidence, hasLength(2));
        expect(candidateB.evidence, hasLength(1));
      });

      test('LF-17.3.4 - ECB A no elimina B aportado por fondos.json', () {
        final resolution = IsinResolution.fromSourceResults(<List<IsinResult>>[
          <IsinResult>[candidateAFromCnmv],
          <IsinResult>[candidateAFromFondos, candidateBFromFondos],
          <IsinResult>[candidateAFromEcb],
        ]);

        expect(
          resolution.candidates.map((candidate) => candidate.isin).toSet(),
          <String>{'ES0000000001', 'ES0000000002'},
        );

        final candidateB = resolution.candidates.firstWhere(
          (candidate) => candidate.isin == 'ES0000000002',
        );

        expect(candidateB.evidence, hasLength(1));
        expect(candidateB.evidence.single.source, 'fondos.json');
      });

      test('LF-17.3.5 - A + B + C procedentes de varias fuentes '
          'conserva los tres', () {
        final resolution = IsinResolution.fromSourceResults(<List<IsinResult>>[
          <IsinResult>[candidateAFromCnmv],
          <IsinResult>[candidateAFromFondos, candidateBFromFondos],
          <IsinResult>[candidateBFromEcb, candidateCFromEcb],
        ]);

        expect(
          resolution.candidates.map((candidate) => candidate.isin).toSet(),
          <String>{'ES0000000001', 'ES0000000002', 'ES0000000003'},
        );

        final candidateA = resolution.candidates.firstWhere(
          (candidate) => candidate.isin == 'ES0000000001',
        );

        final candidateB = resolution.candidates.firstWhere(
          (candidate) => candidate.isin == 'ES0000000002',
        );

        final candidateC = resolution.candidates.firstWhere(
          (candidate) => candidate.isin == 'ES0000000003',
        );

        expect(candidateA.evidence, hasLength(2));
        expect(candidateB.evidence, hasLength(2));
        expect(candidateC.evidence, hasLength(1));
      });

      test('LF-17.3.6 - tres apariciones del mismo ISIN '
          'producen un solo candidato con tres evidencias', () {
        final resolution = IsinResolution.fromSourceResults(<List<IsinResult>>[
          <IsinResult>[candidateAFromCnmv],
          <IsinResult>[candidateAFromFondos],
          <IsinResult>[candidateAFromEcb],
        ]);

        expect(resolution.candidates, hasLength(1));

        final candidate = resolution.candidates.single;

        expect(candidate.isin, 'ES0000000001');
        expect(candidate.evidence, hasLength(3));

        expect(
          candidate.evidence.map((e) => e.source),
          containsAll(<String>['CNMV', 'fondos.json', 'ECB']),
        );
      });

      test(
        'LF-17.3.7 - las fuentes no pueden provocar pérdida de candidatos',
        () {
          final resolution = IsinResolution.fromSourceResults(
            <List<IsinResult>>[
              <IsinResult>[candidateAFromCnmv],
              <IsinResult>[candidateAFromFondos, candidateBFromFondos],
              <IsinResult>[candidateBFromEcb, candidateCFromEcb],
            ],
          );

          final isins = resolution.candidates
              .map((candidate) => candidate.isin)
              .toSet();

          expect(isins.length, 3);
          expect(
            isins,
            containsAll(<String>[
              'ES0000000001',
              'ES0000000002',
              'ES0000000003',
            ]),
          );
        },
      );
    });

    // -----------------------------------------------------------------------
    // LF-17.4 - Evidencia y enriquecimiento
    //
    // Aquí NO se establece todavía ninguna prioridad entre fuentes.
    // Se comprueba únicamente que:
    //   - no se pierde evidencia;
    //   - campos presentes en distintas evidencias pueden coexistir;
    //   - un conflicto de metadatos no elimina una de las evidencias.
    // -----------------------------------------------------------------------

    group('LF-17.4 - evidencia y enriquecimiento', () {
      test('LF-17.4.1 - una fuente no elimina un candidato adicional', () {
        final resolution = IsinResolution.fromSourceResults(<List<IsinResult>>[
          <IsinResult>[candidateAFromCnmv],
          <IsinResult>[candidateAFromFondos, candidateBFromFondos],
        ]);

        expect(resolution.candidates, hasLength(2));
      });

      test(
        'LF-17.4.2 - dos evidencias del mismo ISIN permanecen disponibles',
        () {
          final resolution = IsinResolution.fromSourceResults(
            <List<IsinResult>>[
              <IsinResult>[candidateAFromCnmv],
              <IsinResult>[candidateAFromFondos],
            ],
          );

          final candidate = resolution.candidates.single;

          expect(candidate.evidence, hasLength(2));

          expect(
            candidate.evidence.map((e) => e.source),
            containsAll(<String>['CNMV', 'fondos.json']),
          );
        },
      );

      test('LF-17.4.3 - campos presentes en una segunda evidencia '
          'no desaparecen del conjunto de evidencias', () {
        const primary = IsinResult(
          isin: 'ES0000000010',
          source: 'CNMV',
          officialName: 'Nombre oficial',
        );

        const enrichment = IsinResult(
          isin: 'ES0000000010',
          source: 'fondos.json',
          cnmvRegistration: 1234,
          cnmvNif: 'V12345678',
        );

        final resolution = IsinResolution.fromSourceResults(<List<IsinResult>>[
          <IsinResult>[primary],
          <IsinResult>[enrichment],
        ]);

        final candidate = resolution.candidates.single;

        expect(candidate.evidence, hasLength(2));

        final cnmv = candidate.evidence.firstWhere(
          (result) => result.source == 'CNMV',
        );

        final fondos = candidate.evidence.firstWhere(
          (result) => result.source == 'fondos.json',
        );

        expect(cnmv.officialName, 'Nombre oficial');
        expect(cnmv.cnmvRegistration, isNull);
        expect(cnmv.cnmvNif, isNull);

        expect(fondos.officialName, isNull);
        expect(fondos.cnmvRegistration, 1234);
        expect(fondos.cnmvNif, 'V12345678');
      });

      test(
        'LF-17.4.4 - un conflicto de metadatos no elimina ninguna evidencia',
        () {
          const first = IsinResult(
            isin: 'ES0000000011',
            source: 'CNMV',
            officialName: 'Nombre CNMV',
            cnmvRegistration: 1100,
          );

          const second = IsinResult(
            isin: 'ES0000000011',
            source: 'fondos.json',
            officialName: 'Nombre fondos.json',
            cnmvRegistration: 2200,
          );

          final resolution = IsinResolution.fromSourceResults(
            <List<IsinResult>>[
              <IsinResult>[first],
              <IsinResult>[second],
            ],
          );

          final candidate = resolution.candidates.single;

          expect(candidate.evidence, hasLength(2));

          expect(
            candidate.evidence.map((e) => e.officialName),
            containsAll(<String>['Nombre CNMV', 'Nombre fondos.json']),
          );

          expect(
            candidate.evidence.map((e) => e.cnmvRegistration),
            containsAll(<int>[1100, 2200]),
          );
        },
      );

      test('LF-17.4.5 - la evidencia conserva la identidad del ISIN', () {
        const first = IsinResult(isin: 'ES0000000012', source: 'CNMV');

        const second = IsinResult(isin: 'ES0000000012', source: 'fondos.json');

        final resolution = IsinResolution.fromSourceResults(<List<IsinResult>>[
          <IsinResult>[first],
          <IsinResult>[second],
        ]);

        final candidate = resolution.candidates.single;

        expect(candidate.isin, 'ES0000000012');

        for (final evidence in candidate.evidence) {
          expect(evidence.isin, candidate.isin);
        }
      });
    });

    // -----------------------------------------------------------------------
    // LF-17.5 - Orden, estabilidad e inmutabilidad
    // -----------------------------------------------------------------------

    group('LF-17.5 - orden, estabilidad e inmutabilidad', () {
      test('LF-17.5.1 - el orden de primera aparición determina '
          'el orden de candidatos', () {
        final resolution = IsinResolution.fromSourceResults(<List<IsinResult>>[
          <IsinResult>[candidateAFromCnmv],
          <IsinResult>[candidateBFromFondos],
          <IsinResult>[candidateCFromEcb],
        ]);

        expect(
          resolution.candidates.map((candidate) => candidate.isin).toList(),
          <String>['ES0000000001', 'ES0000000002', 'ES0000000003'],
        );
      });

      test('LF-17.5.2 - un duplicado no altera el orden '
          'de primera aparición', () {
        final resolution = IsinResolution.fromSourceResults(<List<IsinResult>>[
          <IsinResult>[candidateAFromCnmv],
          <IsinResult>[candidateAFromFondos, candidateBFromFondos],
          <IsinResult>[candidateCFromEcb],
        ]);

        expect(
          resolution.candidates.map((candidate) => candidate.isin).toList(),
          <String>['ES0000000001', 'ES0000000002', 'ES0000000003'],
        );
      });

      test('LF-17.5.3 - repetir la misma agregación produce '
          'el mismo resultado', () {
        final sourceResults = <List<IsinResult>>[
          <IsinResult>[candidateAFromCnmv],
          <IsinResult>[candidateAFromFondos, candidateBFromFondos],
          <IsinResult>[candidateBFromEcb, candidateCFromEcb],
        ];

        final first = IsinResolution.fromSourceResults(sourceResults);
        final second = IsinResolution.fromSourceResults(sourceResults);

        expect(
          first.candidates.map((candidate) => candidate.isin).toList(),
          second.candidates.map((candidate) => candidate.isin).toList(),
        );

        for (var i = 0; i < first.candidates.length; i++) {
          expect(
            first.candidates[i].evidence.map((e) => e.source).toList(),
            second.candidates[i].evidence.map((e) => e.source).toList(),
          );
        }
      });

      test('LF-17.5.4 - las listas expuestas son inmutables', () {
        final resolution = IsinResolution.fromSourceResults(<List<IsinResult>>[
          <IsinResult>[candidateAFromCnmv],
          <IsinResult>[candidateBFromFondos],
        ]);

        // expect(
        //   () => resolution.candidates.add(
        //     const IsinCandidate(
        //       isin: 'ES0000000003',
        //       evidence: <IsinResult>[candidateCFromEcb],
        //     ),
        //   ),
        //   throwsUnsupportedError,
        // );
        // expect(
        //   () => resolution.candidates.single.evidence.add(candidateAFromEcb),
        //   throwsUnsupportedError,
        // );

        expect(
          () => resolution.candidates.add(
            const IsinCandidate(isin: 'ES0000000099', evidence: <IsinResult>[]),
          ),
          throwsUnsupportedError,
        );

        expect(
          () => resolution.candidates.first.evidence.add(candidateAFromEcb),
          throwsUnsupportedError,
        );
      });
    });
  });
}
