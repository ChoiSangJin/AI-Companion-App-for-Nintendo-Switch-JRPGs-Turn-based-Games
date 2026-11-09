/* Executes upstream TypeScript fusion functions with Node's official type eraser.
   No independently reimplemented averaging formula generates these expectations.
   Usage: node tools/reference_fusions.cjs /path/to/megaten-fusion-tool
   Fixture tuples are [ingredient index, other index, result index].
*/
const fs=require('node:fs'),path=require('node:path');
const {stripTypeScriptTypes}=require('node:module');
const root=process.argv[2];if(!root)throw Error('Pass upstream checkout path');
function load(file,names,extra={}){
 let code=fs.readFileSync(path.join(root,'src/app/compendium/fusions',file+'.ts'),'utf8');
 code=code.replace(/import[\s\S]*?from\s+['"][^'"]+['"];?/g,'').replace(/export /g,'');
 code=stripTypeScriptTypes(code,{mode:'transform',disableExperimentalWarning:true});
 return Function(...Object.keys(extra),code+'\nreturn {'+names.join(',')+'};')(...Object.values(extra));
}
const normal=load('smt-nonelem-fusions',['fuseWithDiffRace','fuseWithSameRace','fuseWithElement']);
const same=load('per-nonelem-fusions',['fuseWithSameRace']);
const elem=load('smt-element-fusions',['fuseWithNormResult','fuseWithSpecResult']);
const two=load('per-element-fusions',['fuseTwoElements']);
const trio=load('per-triple-fusions',['fuseT1WithDiffRace','fuseN1WithDiffRace','fuseWithSameRace'],{fuseWithElement:normal.fuseWithElement});
function adapter(g,enabled){
 const all=Object.fromEntries(g.demons.map(d=>[d.id,{...d,name:d.id,lvl:d.level,currLvl:d.level}]));
 const active=g.demons.filter(d=>!d.dlc||enabled.includes(d.dlc));const activeIds=new Set(active.map(d=>d.id));
 const pool=(race,result)=>active.filter(d=>d.race===race&&(result?!Object.hasOwn(g.special,d.id):!g.elements.includes(d.id))).map(d=>d.level).sort((a,b)=>a-b);
 const comp={getDemon:n=>all[n],isElementDemon:n=>g.elements.includes(n),getIngredientDemonLvls:r=>pool(r,false),getResultDemonLvls:r=>pool(r,true),reverseLookupDemon:(r,l)=>g.demons.find(d=>d.race===r&&d.level===l)?.id,reverseLookupSpecial:n=>Object.keys(g.special).filter(k=>g.special[k].length===2&&g.special[k].includes(n)&&activeIds.has(k)),getSpecialNameEntries:n=>g.special[n]||[],get specialDemons(){return Object.keys(g.special).filter(n=>!g.elements.includes(n)).map(n=>all[n]);}};
 function chart(table,mod){return {lvlModifier:mod,raceOrder:Object.fromEntries(g.races.map((r,i)=>[r,i])),elementDemons:g.elements,getRaceFusions:r=>table[r]||{},getRaceFissions:r=>{const out={};for(const[a,bs]of Object.entries(table))for(const[b,v]of Object.entries(bs))if(v===r)(out[a]??=[]).push(b);return out;},getElemFusions:e=>g.elementChart[e]||{},getElemModifiers:r=>{const out={};for(const[e,rs]of Object.entries(g.elementChart))if(rs[r])(out[rs[r]]??=[]).push(e);return out;}};}
 return {comp,chart:chart(g.normalChart,g.id==='smt5v'?1:0.5),square:{normalChart:chart(g.normalChart,0.5),tripleChart:chart(g.tripleChart,4.25)},active};
}
const fixtures=[];
for(const game of ['p3r','p4g','p5r','smt5v']){
 const g=JSON.parse(fs.readFileSync(`assets/megaten/${game}.json`));const names=g.demons.map(d=>d.id).sort();const ni=Object.fromEntries(names.map((n,i)=>[n,i]));
 const profiles=[[],g.dlc.map(d=>d.id)];if(g.dlc.length>1)profiles.push([g.dlc[0].id]);
 for(const enabled of profiles.filter((p,i,a)=>a.findIndex(x=>JSON.stringify(x)===JSON.stringify(p))===i)){
  const {comp,chart,active}=adapter(g,enabled);const activeSet=new Set(active.map(d=>d.id));const tuples=new Set();
  for(const d of active){
   const isElem=g.elements.includes(d.id);
   const functions=isElem?(game==='p5r'?[elem.fuseWithNormResult,elem.fuseWithSpecResult,two.fuseTwoElements]:game==='smt5v'?[elem.fuseWithNormResult,elem.fuseWithSpecResult]:[]):[normal.fuseWithDiffRace,game==='smt5v'?normal.fuseWithSameRace:same.fuseWithSameRace,...(game==='p5r'||game==='smt5v'?[normal.fuseWithElement]:[])];
   for(const f of functions)for(const pair of f(d.id,comp,chart))if(activeSet.has(pair.name1)&&activeSet.has(pair.name2)&&pair.name1!==d.id&&pair.name2!==d.id&&pair.name2!==pair.name1){const indices=[ni[d.id],ni[pair.name1]].sort((a,b)=>a-b);tuples.add([...indices,ni[pair.name2]].join(','));}
  }
  for(const[result,inputs]of Object.entries(g.special))if(inputs.length===2&&activeSet.has(result)&&inputs.every(n=>activeSet.has(n)))tuples.add([...inputs.map(n=>ni[n]).sort((a,b)=>a-b),ni[result]].join(','));
  // Only ordinary non-element pairs are required to match symmetrically;
  // upstream's two orientations of special+element disagree at some boundaries.
  const pairTuples=[...tuples].map(t=>t.split(',').map(Number)).filter(([a,b])=>!g.elements.includes(names[a])&&!g.elements.includes(names[b]));
  const elementCases=[];
  for(const d of active.filter(d=>!g.elements.includes(d.id)))for(const pair of normal.fuseWithElement(d.id,comp,chart))if(activeSet.has(pair.name1)&&activeSet.has(pair.name2)&&pair.name2!==d.id)elementCases.push([ni[d.id],ni[pair.name1],ni[pair.name2]]);
  if(game==='p5r')for(const name of g.elements)for(const pair of two.fuseTwoElements(name,comp,chart))if(activeSet.has(pair.name1)&&activeSet.has(pair.name2))elementCases.push([ni[name],ni[pair.name1],ni[pair.name2]]);
  fixtures.push({game,enabled,names,pairs:pairTuples,elements:elementCases});console.log(game,enabled.length,'DLC groups',pairTuples.length,'reference pairs');
 }
 if(game==='p4g'){
  const{comp,square,active}=adapter(g,[]);let samples=[];
  for(const demon of active.filter((_,i)=>i%17===0)){
   for(const recipe of trio.fuseT1WithDiffRace(demon.id,comp,square).slice(0,25)){
    if([recipe.name1,recipe.name2,recipe.name3].every(n=>ni[n]!==undefined))samples.push({inputs:[demon.id,recipe.name1,recipe.name2],result:recipe.name3});
   }
  }
  for(const demon of active.filter((_,i)=>i%17===0))for(const recipe of trio.fuseWithSameRace(demon.id,comp,square).slice(0,12))if([recipe.name1,recipe.name2,recipe.name3].every(n=>ni[n]!==undefined))samples.push({inputs:[demon.id,recipe.name1,recipe.name2],result:recipe.name3});
  for(const id of ['Pixie','Jack Frost','King Frost']){
   comp.getDemon(id).currLvl=80;
   for(const recipe of trio.fuseT1WithDiffRace(id,comp,square).slice(0,40))if([recipe.name1,recipe.name2,recipe.name3].every(n=>ni[n]!==undefined))samples.push({inputs:[id,recipe.name1,recipe.name2],result:recipe.name3,current:{[id]:80}});
   comp.getDemon(id).currLvl=comp.getDemon(id).lvl;
  }
  fs.writeFileSync('test/fixtures/upstream_triples.json',JSON.stringify(samples));console.log('P4G triple cases',samples.length);
 }
}
fs.writeFileSync('test/fixtures/upstream_pairs.json',JSON.stringify(fixtures));
