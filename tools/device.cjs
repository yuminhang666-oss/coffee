const fs=require('node:fs');
const path=require('node:path');
const {execFileSync}=require('node:child_process');
const adbPath='D:/Codex/PocketFlowTools/android-sdk/platform-tools/adb.exe';
const device=process.env.ANDROID_SERIAL||'emulator-5586';
const evidence=path.resolve(process.env.COFFEE_EVIDENCE||path.join(__dirname,'../deliverables/v0.2.0/evidence'));
const pkg='cn.coffeejournal.coffee_journal';
fs.mkdirSync(evidence,{recursive:true});
function adb(...args){return execFileSync(adbPath,['-s',device,...args]);}
function decode(s){return s.replace(/&#(\d+);/g,(_,n)=>String.fromCharCode(Number(n))).replace(/&quot;/g,'"').replace(/&amp;/g,'&').replace(/&lt;/g,'<').replace(/&gt;/g,'>');}
function nodes(){let success=false;for(let i=0;i<3;i++){const output=adb('shell','uiautomator','dump','/sdcard/coffee-qa-window.xml').toString();if(output.includes('dumped')){success=true;break;}Atomics.wait(new Int32Array(new SharedArrayBuffer(4)),0,0,700);}if(!success)throw Error('UI dump unavailable');return [...adb('shell','cat','/sdcard/coffee-qa-window.xml').toString().matchAll(/<node\b([^>]+)>/g)].map(m=>Object.fromEntries([...m[1].matchAll(/([\w-]+)="([^"]*)"/g)].map(a=>[a[1],decode(a[2])])));}
function tap(label){const matches=nodes().filter(n=>[n.text,n['content-desc'],n.hint].some(s=>s===label||s?.split('\n').includes(label)||s?.startsWith(label)));const n=matches.find(n=>n.clickable==='true')||matches[0];if(!n)throw Error('Not visible: '+label);const b=n.bounds.match(/\d+/g).map(Number);adb('shell','input','tap',String(Math.round((b[0]+b[2])/2)),String(Math.round((b[1]+b[3])/2)));}
function screenshot(name){const file=path.join(evidence,name+'.png');fs.writeFileSync(file,adb('exec-out','screencap','-p'));console.log(file);}
const [action,...values]=process.argv.slice(2);const value=values.join(' ');
if(action==='nodes')console.log(JSON.stringify(nodes().filter(n=>n.text||n['content-desc']||n.hint).map(n=>({text:n.text,label:n['content-desc'],hint:n.hint,bounds:n.bounds,clickable:n.clickable,class:n.class})),null,2));
else if(action==='tap')tap(value);
else if(action==='fill'){const hint=values[0],value=values.slice(1).join(' ');const n=nodes().find(n=>n.hint===hint||n.hint?.startsWith(hint));if(!n)throw Error('No field: '+hint);tap(hint);adb('shell','input','keyevent','123');if(n.text)adb('shell','input','keyevent',...Array(n.text.length).fill('67'));adb('shell','input','text',value);}
else if(action==='screenshot')screenshot(value);
else if(action==='text')adb('shell','input','text',value);
else if(action==='swipe')adb('shell','input','swipe',...values);
else if(action==='back')adb('shell','input','keyevent','4');
else if(action==='restart'){adb('shell','am','force-stop',pkg);adb('shell','am','start','-n',pkg+'/.MainActivity');}
else if(action==='state')console.log(adb('shell','run-as',pkg,'cat','files/coffee-v1.json').toString());
else throw Error('Unknown action');
if(['tap','back','swipe','restart'].includes(action))setTimeout(()=>{},action==='restart'?4500:800);
