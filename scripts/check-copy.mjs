import {readFile} from 'node:fs/promises';
// A deterministic regression guard, paired with the scheduled agent's Russian proofreading.
// This is deliberately not advertised as a complete grammar checker.
const files=['src/App.tsx','src/Admin.tsx','src/types.ts','src/lib.ts','index.html'];
const banned=[/Не знаешь,? что подарить/iu,/НЕМНОГО ОБО МНЕ/iu,/О МЕЧТАХ/iu,/радует сердце/iu,/сделает меня счастливее/iu,/собрано с любовью/iu,/маленький секрет/iu,/Мастерская желаний/iu,/finder-banner|setFinder|finderType/u,/\uFFFD/u];
const problems=[];
for(const file of files){const source=await readFile(file,'utf8');for(const rule of banned)if(rule.test(source))problems.push(`${file}: ${rule}`)}
if(problems.length){console.error(problems.join('\n'));process.exitCode=1}else console.log('UI copy regression checks passed. Full grammar and tone review belongs to the scheduled AI audit.');
