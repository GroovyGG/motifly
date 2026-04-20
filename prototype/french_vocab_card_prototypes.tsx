export default function FrenchVocabCardPrototypes() {
  const CollapsibleSection = ({ title, children, defaultOpen = false }) => (
    <details className="group border-t px-5 py-4" open={defaultOpen}>
      <summary className="flex cursor-pointer list-none items-center justify-between text-sm font-semibold text-slate-700 marker:content-none">
        <span>{title}</span>
        <span className="text-slate-400 transition-transform group-open:rotate-180">⌄</span>
      </summary>
      <div className="mt-3">{children}</div>
    </details>
  );

  const Card = ({ children, className = "" }) => (
    <div className={`rounded-3xl border bg-white shadow-sm ${className}`}>{children}</div>
  );

  const Section = ({ title, children }) => (
    <div className="border-t px-5 py-4">
      <div className="mb-3 text-sm font-semibold text-slate-700">{title}</div>
      {children}
    </div>
  );

  const SectionlessBlock = ({ children }) => <div className="border-t px-5 py-4">{children}</div>;

  const AudioButton = ({ label = "Play" }) => (
    <button className="rounded-xl border px-2.5 py-1.5 text-xs font-medium text-slate-700 hover:bg-slate-50">
      🔊 {label}
    </button>
  );

  const SmallStat = ({ label, value }) => (
    <div className="rounded-2xl bg-slate-50 px-3 py-2">
      <div className="text-xs text-slate-500">{label}</div>
      <div className="text-sm font-semibold text-slate-800">{value}</div>
    </div>
  );

  const EditableNote = ({ children }) => (
    <div className="rounded-2xl bg-amber-50 p-3 text-sm text-slate-700">
      <div className="mb-2 flex items-center justify-end text-slate-500">✏️</div>
      {children}
    </div>
  );

  return (
    <div className="min-h-screen bg-slate-50 p-6 md:p-10">
      <div className="mx-auto max-w-screen-2xl">
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-slate-900">French Dictation App — Vocabulary Card Prototypes</h1>
          <p className="mt-2 max-w-3xl text-slate-600">
            Unified card system with shared learning blocks and type-specific grammar modules.
          </p>
        </div>

        <div className="mb-10 grid gap-4 md:grid-cols-4">
          <Card className="p-4">
            <div className="text-sm text-slate-500">General</div>
            <div className="mt-1 text-lg font-semibold">Header · Translation · Example · Audio · Progress</div>
          </Card>
          <Card className="p-4">
            <div className="text-sm text-slate-500">Noun</div>
            <div className="mt-1 text-lg font-semibold text-slate-700">Gender · Article · Plural</div>
          </Card>
          <Card className="p-4">
            <div className="text-sm text-slate-500">Verb</div>
            <div className="mt-1 text-lg font-semibold text-green-700">Core forms · Conjugation</div>
          </Card>
          <Card className="p-4">
            <div className="text-sm text-slate-500">Adjective</div>
            <div className="mt-1 text-lg font-semibold text-violet-700">Masc/Fem · Agreement</div>
          </Card>
        </div>

        <div className="grid gap-8 xl:grid-cols-2 2xl:grid-cols-4">
          <Card className="overflow-hidden border-slate-200">
            <div className="bg-slate-50 px-5 py-4">
              <div className="flex items-start justify-between gap-4">
                <div>
                  <div className="flex items-center gap-2 text-3xl font-bold">
                    <span className="text-2xl" aria-hidden="true">👧</span>
                    <span className="text-rose-600">voiture</span>
                  </div>
                  <div className="mt-2 text-sm font-medium text-slate-500">Noun</div>
                </div>
                <div className="flex flex-col gap-2">
                  <AudioButton label="French" />
                  <AudioButton label="Mine" />
                </div>
              </div>
            </div>

            <SectionlessBlock>
              <div className="space-y-2">
                <div className="rounded-2xl bg-slate-50 px-3 py-2">
                  <div className="text-xs text-slate-500">English</div>
                  <div className="text-sm font-medium text-slate-800">car</div>
                </div>
                <div className="rounded-2xl bg-slate-50 px-3 py-2">
                  <div className="text-xs text-slate-500">中文</div>
                  <div className="text-sm font-medium text-slate-800">汽车，车</div>
                </div>
              </div>
            </SectionlessBlock>

            <Section title="Example Sentence">
              <div className="rounded-2xl bg-slate-50 p-3 text-slate-800">
                Mettez votre <span className="font-semibold text-rose-600">voiture</span> dans le parking.
              </div>
              <div className="mt-2 text-sm text-slate-500">把你的车停到停车场里。</div>
            </Section>

            <CollapsibleSection title="Article & Plural" defaultOpen={false}>
              <div className="grid gap-3 sm:grid-cols-2">
                <div className="rounded-2xl bg-slate-50 p-3">
                  <div className="text-xs text-slate-500">Article</div>
                  <div className="mt-1 text-lg font-semibold">
                    <span className="text-rose-600">la</span> <span className="text-rose-600">voiture</span>
                  </div>
                  <div className="mt-1 text-sm text-slate-500">
                    <span className="text-slate-700">une</span> <span className="text-rose-600">voiture</span>
                  </div>
                </div>
                <div className="rounded-2xl bg-slate-50 p-3">
                  <div className="text-xs text-slate-500">Plural</div>
                  <div className="mt-1 text-lg font-semibold text-rose-600">les voitures</div>
                  <div className="mt-1 text-sm text-slate-500">regular plural</div>
                </div>
              </div>
            </CollapsibleSection>

            <CollapsibleSection title="Memory Support" defaultOpen={false}>
              <div className="grid gap-3 sm:grid-cols-[96px_1fr]">
                <div className="flex h-24 items-center justify-center rounded-2xl bg-slate-100 text-sm text-slate-500">Image</div>
                <EditableNote>
                  Always memorize with article. Think <span className="font-semibold text-rose-600">la voiture</span>, not only{' '}
                  <span className="font-semibold text-rose-600">voiture</span>.
                </EditableNote>
              </div>
            </CollapsibleSection>

            <Section title="Progress">
              <div className="grid grid-cols-2 gap-3">
                <SmallStat label="Accuracy" value="78%" />
                <SmallStat label="Attempts" value="12" />
              </div>
              <div className="mt-4 border-t pt-4">
                <div className="mb-3 text-sm font-semibold text-slate-700">Errored Attempts</div>
                <div className="space-y-2 font-mono text-sm text-slate-800">
                  <div>
                    voit<span className="border-b-2 border-red-500 text-red-600">u</span><span className="border-b-2 border-red-500 text-red-600">e</span>r <span className="ml-2 text-xs text-slate-500">×4</span>
                  </div>
                  <div>
                    vo<span className="border-b-2 border-red-500 text-red-600">i</span>ture <span className="ml-2 text-xs text-slate-500">×2</span>
                  </div>
                  <div>
                    voitu<span className="border-b-2 border-red-500 text-red-600">r</span><span className="border-b-2 border-red-500 text-red-600">e</span>s <span className="ml-2 text-xs text-slate-500">×1</span>
                  </div>
                </div>
              </div>
            </Section>
          </Card>

          <Card className="overflow-hidden border-slate-200">
            <div className="bg-slate-50 px-5 py-4">
              <div className="flex items-start justify-between gap-4">
                <div>
                  <div className="flex items-center gap-2 text-3xl font-bold">
                    <span className="text-2xl" aria-hidden="true">👦</span>
                    <span className="text-blue-900">problème</span>
                  </div>
                  <div className="mt-2 text-sm font-medium text-slate-500">Noun</div>
                </div>
                <div className="flex flex-col gap-2">
                  <AudioButton label="French" />
                  <AudioButton label="Mine" />
                </div>
              </div>
            </div>

            <SectionlessBlock>
              <div className="space-y-2">
                <div className="rounded-2xl bg-slate-50 px-3 py-2">
                  <div className="text-xs text-slate-500">English</div>
                  <div className="text-sm font-medium text-slate-800">problem</div>
                </div>
                <div className="rounded-2xl bg-slate-50 px-3 py-2">
                  <div className="text-xs text-slate-500">中文</div>
                  <div className="text-sm font-medium text-slate-800">问题</div>
                </div>
              </div>
            </SectionlessBlock>

            <Section title="Example Sentence">
              <div className="rounded-2xl bg-slate-50 p-3 text-slate-800">
                Il y a un autre <span className="font-semibold text-blue-900">problème</span>.
              </div>
              <div className="mt-2 text-sm text-slate-500">还有另一个问题。</div>
            </Section>

            <CollapsibleSection title="Article & Plural" defaultOpen={false}>
              <div className="grid gap-3 sm:grid-cols-2">
                <div className="rounded-2xl bg-slate-50 p-3">
                  <div className="text-xs text-slate-500">Article</div>
                  <div className="mt-1 text-lg font-semibold text-blue-900">le problème</div>
                  <div className="mt-1 text-sm text-slate-500">
                    <span className="text-slate-700">un</span> <span className="text-blue-900">problème</span>
                  </div>
                </div>
                <div className="rounded-2xl bg-slate-50 p-3">
                  <div className="text-xs text-slate-500">Plural</div>
                  <div className="mt-1 text-lg font-semibold text-blue-900">les problèmes</div>
                  <div className="mt-1 text-sm text-slate-500">regular plural</div>
                </div>
              </div>
            </CollapsibleSection>

            <CollapsibleSection title="Memory Support" defaultOpen={false}>
              <EditableNote>
                Watch the accent in <span className="font-semibold text-blue-900">problème</span>. Do not flatten it into plain <span className="font-semibold">probleme</span>.
              </EditableNote>
            </CollapsibleSection>

            <Section title="Progress">
              <div className="grid grid-cols-2 gap-3">
                <SmallStat label="Accuracy" value="82%" />
                <SmallStat label="Attempts" value="9" />
              </div>
              <div className="mt-4 border-t pt-4">
                <div className="mb-3 text-sm font-semibold text-slate-700">Errored Attempts</div>
                <div className="space-y-2 font-mono text-sm text-slate-800">
                  <div>
                    probl<span className="border-b-2 border-red-500 text-red-600">e</span>me <span className="ml-2 text-xs text-slate-500">×3</span>
                  </div>
                  <div>
                    prob<span className="border-b-2 border-red-500 text-red-600">l</span>ème <span className="ml-2 text-xs text-slate-500">×2</span>
                  </div>
                  <div>
                    pro<span className="border-b-2 border-red-500 text-red-600">b</span>blème <span className="ml-2 text-xs text-slate-500">×1</span>
                  </div>
                </div>
              </div>
            </Section>
          </Card>

          <Card className="overflow-hidden border-slate-200">
            <div className="bg-slate-50 px-5 py-4">
              <div className="flex items-start justify-between gap-4">
                <div>
                  <div className="text-3xl font-bold text-green-700">parler</div>
                  <div className="mt-2 flex items-center gap-2 text-sm font-medium text-slate-500">
                    <span>Verb</span>
                    <span className="text-slate-300">•</span>
                    <span className="text-green-700">1er groupe</span>
                  </div>
                </div>
                <div className="flex flex-col gap-2">
                  <AudioButton label="French" />
                  <AudioButton label="Mine" />
                </div>
              </div>
            </div>

            <SectionlessBlock>
              <div className="space-y-2">
                <div className="rounded-2xl bg-slate-50 px-3 py-2">
                  <div className="text-xs text-slate-500">English</div>
                  <div className="text-sm font-medium text-slate-800">to speak</div>
                </div>
                <div className="rounded-2xl bg-slate-50 px-3 py-2">
                  <div className="text-xs text-slate-500">中文</div>
                  <div className="text-sm font-medium text-slate-800">说话，讲话</div>
                </div>
              </div>
            </SectionlessBlock>

            <Section title="Example Sentence">
              <div className="rounded-2xl bg-slate-50 p-3 text-slate-800">
                Je <span className="font-semibold text-green-700">parle</span> français tous les jours.
              </div>
              <div className="mt-2 text-sm text-slate-500">我每天都说法语。</div>
            </Section>

            <CollapsibleSection title="Core Forms" defaultOpen={false}>
              <div className="grid gap-3 sm:grid-cols-2">
                <div className="rounded-2xl bg-slate-50 p-3">
                  <div className="text-xs text-slate-500">Infinitive</div>
                  <div className="mt-1 text-lg font-semibold text-green-700">parler</div>
                </div>
                <div className="rounded-2xl bg-slate-50 p-3">
                  <div className="text-xs text-slate-500">Passé composé helper</div>
                  <div className="mt-1 text-lg font-semibold">avoir + parlé</div>
                </div>
              </div>
            </CollapsibleSection>

            <CollapsibleSection title="Present Tense Mini Table" defaultOpen={false}>
              <div className="grid grid-cols-2 gap-2 text-sm">
                {[
                  ['je', 'parle'],
                  ['tu', 'parles'],
                  ['il/elle', 'parle'],
                  ['nous', 'parlons'],
                  ['vous', 'parlez'],
                  ['ils/elles', 'parlent'],
                ].map(([p, f]) => (
                  <div key={p} className="flex items-center justify-between rounded-2xl bg-slate-50 px-3 py-2">
                    <span className="text-slate-500">{p}</span>
                    <span className="font-semibold text-slate-800">{f}</span>
                  </div>
                ))}
              </div>
            </CollapsibleSection>

            <CollapsibleSection title="Passé Composé Mini Table" defaultOpen={false}>
              <div className="grid grid-cols-2 gap-2 text-sm">
                {[
                  ['j’', 'ai parlé'],
                  ['tu', 'as parlé'],
                  ['il/elle', 'a parlé'],
                  ['nous', 'avons parlé'],
                  ['vous', 'avez parlé'],
                  ['ils/elles', 'ont parlé'],
                ].map(([p, f]) => (
                  <div key={p} className="flex items-center justify-between rounded-2xl bg-slate-50 px-3 py-2">
                    <span className="text-slate-500">{p}</span>
                    <span className="font-semibold text-slate-800">{f}</span>
                  </div>
                ))}
              </div>
            </CollapsibleSection>

            <CollapsibleSection title="Memory Support" defaultOpen={false}>
              <EditableNote>
                Hear the silent ending difference: <span className="font-semibold">parle / parles / parlent</span> look different, often sound the same.
              </EditableNote>
            </CollapsibleSection>

            <Section title="Progress">
              <div className="grid grid-cols-2 gap-3">
                <SmallStat label="Accuracy" value="71%" />
                <SmallStat label="Attempts" value="18" />
              </div>
              <div className="mt-4 border-t pt-4">
                <div className="mb-3 text-sm font-semibold text-slate-700">Errored Attempts</div>
                <div className="space-y-2 font-mono text-sm text-slate-800">
                  <div>
                    parl<span className="border-b-2 border-red-500 text-red-600">l</span>er <span className="ml-2 text-xs text-slate-500">×5</span>
                  </div>
                  <div>
                    par<span className="border-b-2 border-red-500 text-red-600">r</span>ler <span className="ml-2 text-xs text-slate-500">×2</span>
                  </div>
                  <div>
                    parle<span className="border-b-2 border-red-500 text-red-600">r</span> <span className="ml-2 text-xs text-slate-500">×1</span>
                  </div>
                </div>
              </div>
            </Section>
          </Card>

          <Card className="overflow-hidden border-slate-200">
            <div className="bg-slate-50 px-5 py-4">
              <div className="flex items-start justify-between gap-4">
                <div>
                  <div className="text-3xl font-bold text-blue-900">heureux</div>
                  <div className="mt-2 text-sm font-medium text-slate-500">Adjective</div>
                </div>
                <div className="flex flex-col gap-2">
                  <AudioButton label="French" />
                  <AudioButton label="Mine" />
                </div>
              </div>
            </div>

            <SectionlessBlock>
              <div className="space-y-2">
                <div className="rounded-2xl bg-slate-50 px-3 py-2">
                  <div className="text-xs text-slate-500">English</div>
                  <div className="text-sm font-medium text-slate-800">happy</div>
                </div>
                <div className="rounded-2xl bg-slate-50 px-3 py-2">
                  <div className="text-xs text-slate-500">中文</div>
                  <div className="text-sm font-medium text-slate-800">高兴的，幸福的</div>
                </div>
              </div>
            </SectionlessBlock>

            <Section title="Example Sentence">
              <div className="rounded-2xl bg-slate-50 p-3 text-slate-800">
                Je suis <span className="font-semibold text-rose-600">heureuse</span> aujourd'hui.
              </div>
              <div className="mt-2 text-sm text-slate-500">我今天很开心。</div>
            </Section>

            <CollapsibleSection title="Agreement Forms" defaultOpen={false}>
              <div className="grid grid-cols-2 gap-3 text-sm">
                <div className="rounded-2xl bg-slate-50 p-3">
                  <div className="text-xs text-blue-600">Masculine singular</div>
                  <div className="mt-1 text-lg font-semibold text-blue-900">heureux</div>
                </div>
                <div className="rounded-2xl bg-slate-50 p-3">
                  <div className="text-xs text-rose-600">Feminine singular</div>
                  <div className="mt-1 text-lg font-semibold text-rose-600">heureuse</div>
                </div>
                <div className="rounded-2xl bg-slate-50 p-3">
                  <div className="text-xs text-blue-600">Masculine plural</div>
                  <div className="mt-1 text-lg font-semibold text-blue-900">heureux</div>
                </div>
                <div className="rounded-2xl bg-slate-50 p-3">
                  <div className="text-xs text-rose-600">Feminine plural</div>
                  <div className="mt-1 text-lg font-semibold text-rose-600">heureuses</div>
                </div>
              </div>
            </CollapsibleSection>

            <CollapsibleSection title="Memory Support" defaultOpen={false}>
              <EditableNote>
                Highlight the shape change: <span className="font-semibold">-eux → -euse</span>. This is not just adding <span className="font-semibold">e</span>.
              </EditableNote>
            </CollapsibleSection>

            <Section title="Progress">
              <div className="grid grid-cols-2 gap-3">
                <SmallStat label="Accuracy" value="74%" />
                <SmallStat label="Attempts" value="10" />
              </div>
              <div className="mt-4 border-t pt-4">
                <div className="mb-3 text-sm font-semibold text-slate-700">Errored Attempts</div>
                <div className="space-y-2 font-mono text-sm text-slate-800">
                  <div>
                    heur<span className="border-b-2 border-red-500 text-red-600">e</span>se <span className="ml-2 text-xs text-slate-500">×4</span>
                  </div>
                  <div>
                    heureu<span className="border-b-2 border-red-500 text-red-600">x</span>e <span className="ml-2 text-xs text-slate-500">×2</span>
                  </div>
                  <div>
                    heure<span className="border-b-2 border-red-500 text-red-600">s</span>e <span className="ml-2 text-xs text-slate-500">×1</span>
                  </div>
                </div>
              </div>
            </Section>
          </Card>
        </div>

        <div className="mt-10 grid gap-6 lg:grid-cols-2">
          <Card className="p-5">
            <h2 className="text-lg font-semibold text-slate-900">Shared Components</h2>
            <div className="mt-4 grid gap-2 text-sm text-slate-700 md:grid-cols-2">
              {[
                'Word header',
                'French audio button',
                'My recording button',
                'English translation',
                'Chinese translation',
                'Example sentence',
                'Example translation',
                'Memory image',
                'Custom note',
                'Progress stats',
                'Top 3 errored spellings',
              ].map((item) => (
                <div key={item} className="rounded-2xl bg-slate-50 px-3 py-2">
                  {item}
                </div>
              ))}
            </div>
          </Card>

          <Card className="p-5">
            <h2 className="text-lg font-semibold text-slate-900">Design Rules</h2>
            <div className="mt-4 space-y-3 text-sm text-slate-700">
              <div className="rounded-2xl bg-slate-50 p-3">Gray top area for all card types</div>
              <div className="rounded-2xl bg-slate-50 p-3">Masculine = deep blue, feminine = pinkish red</div>
              <div className="rounded-2xl bg-slate-50 p-3">English appears above Chinese in the translation stack</div>
              <div className="rounded-2xl bg-slate-50 p-3">Memory Support is collapsible and editable by the user</div>
            </div>
          </Card>
        </div>
      </div>
    </div>
  );
}
