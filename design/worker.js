const $=s=>document.querySelector(s);
const MONTHS=['Oct 2026','Sep 2026','Aug 2026','Jul 2026','Jun 2026','May 2026'];
let G=[
{id:'G1',name:'Chiamaka Obi',phone:'0803 555 0101',status:'New guest',days:4,calls:0,sun:1,wed:0,team:'',fb:'',fbDate:'',fu:0,month:'Oct 2026'},
{id:'G2',name:'Tunde Bakare',phone:'0803 555 0102',status:'Contacted',days:2,calls:1,sun:2,wed:1,team:'',fb:'Enjoyed the service, will be back Sunday.',fbDate:'26 Oct',fu:1,month:'Oct 2026'},
{id:'G3',name:'Esther Adeyemi',phone:'0803 555 0103',status:'Returning',days:12,calls:3,sun:3,wed:2,team:'Workforce',fb:'Asked about joining Workforce.',fbDate:'27 Oct',fu:3,month:'Oct 2026'},
{id:'G4',name:'Samuel Eze',phone:'0803 555 0104',status:'Member',days:20,calls:5,sun:4,wed:2,team:'Evangelism',fb:'Now a member. Joined Evangelism.',fbDate:'25 Oct',fu:5,month:'Oct 2026'},
{id:'G5',name:'Ngozi Umeh',phone:'0803 555 0105',status:'New guest',days:1,calls:0,sun:1,wed:0,team:'',fb:'',fbDate:'',fu:0,month:'Oct 2026'},
{id:'G6',name:'Femi Ajayi',phone:'0803 555 0106',status:'Unreachable',days:15,calls:3,sun:1,wed:0,team:'',fb:'Phone off on 3 tries.',fbDate:'20 Oct',fu:3,month:'Oct 2026'},
{id:'G7',name:'Bola Ogun',phone:'0803 555 0107',status:'Returning',days:40,calls:4,sun:2,wed:1,team:'',fb:'Travelling, back next month.',fbDate:'12 Sep',fu:4,month:'Sep 2026'},
{id:'G8',name:'Dayo Balogun',phone:'0803 555 0108',status:'Member',days:55,calls:6,sun:4,wed:3,team:'Workforce',fb:'Became a member.',fbDate:'30 Sep',fu:6,month:'Sep 2026'},
{id:'G9',name:'Kemi Lawal',phone:'0803 555 0109',status:'Not interested',days:70,calls:2,sun:1,wed:0,team:'',fb:'Prefers another church.',fbDate:'8 Aug',fu:2,month:'Aug 2026'}];
const RANK={'Oct 2026':[['Grace',320],['David',280],['Tolu',240],['Samuel',160],['Ife',90]],'Sep 2026':[['David',410],['Grace',390],['Tolu',300],['Ife',210],['Samuel',120]],'Aug 2026':[['Grace',450],['Tolu',380],['Samuel',330],['Ife',250],['David',210]]};
const S={tab:'today',tile:'all',chip:'all',month:'Oct 2026',rmonth:'Oct 2026',view:null,sheet:false,log:null};
const ICON={today:'<path d="M3 11l9-8 9 8M5 10v10h14V10"/>',guests:'<path d="M8 6h12M8 12h12M8 18h12M4 6h.01M4 12h.01M4 18h.01"/>',rank:'<path d="M8 4h8v5a4 4 0 0 1-8 0V4zM8 6H4v1a3 3 0 0 0 4 2.8M16 6h4v1a3 3 0 0 1-4 2.8M12 13v4M8 20h8M10 17h4"/>',me:'<circle cx="12" cy="8" r="4"/><path d="M4 21c0-4 4-6 8-6s8 2 8 6"/>'};
const prog=g=>g.calls===0?(g.days>3?'r':'b'):(g.calls===1?'a':'g');
const progTxt=g=>g.calls===0?(g.days>3?'Not called · '+g.days+' days':'Call within 3 days'):(g.calls===1?'Called once · follow up':'Followed up');
const initials=n=>n.split(' ').map(x=>x[0]).slice(0,2).join('');
const wa=p=>'https://wa.me/234'+p.replace(/\s/g,'').slice(-10);
const cls={'New guest':'b','Contacted':'a','Returning':'g','Member':'go','Not interested':'n','Unreachable':'r'};
function tabs(){return `<div class="tabs">${[['today','Today'],['guests','Guests'],['rank','Ranking'],['me','Me']].map(([k,l])=>`<button class="tab ${S.tab===k&&!S.view?'on':''}" onclick="go('${k}')"><svg viewBox="0 0 24 24">${ICON[k]}</svg>${l}<i></i></button>`).join('')}</div>`}
function go(t){S.tab=t;S.view=null;S.log=null;render()}
function open_(id){S.view=id;render()}
const CAL='<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#0B1F3A" stroke-width="2.2" stroke-linecap="round"><rect x="3" y="5" width="18" height="16" rx="3"/><path d="M8 3v4M16 3v4M3 10h18"/></svg>';
const BACK=t=>`<button class="back" onclick="S.view=null;S.log=null;render()">‹ ${t}</button>`;
function card(g){const p=prog(g);return `<div class="card guest ${p}" onclick="open_('${g.id}')"><div class="row"><div class="av">${initials(g.name)}</div><div class="grow"><b style="font-size:16px">${g.name}</b><div class="mut">${g.phone}</div></div><span class="pill ${cls[g.status]}">${g.status}</span></div>
<div class="row" style="margin-top:10px"><span class="mut grow" style="color:${p==='r'?'var(--red)':p==='a'?'#8A5300':p==='g'?'var(--green)':'var(--mut)'};font-weight:500">${progTxt(g)}</span>
<a class="pill wa" style="padding:8px 14px;text-decoration:none" href="${wa(g.phone)}" target="_blank" onclick="event.stopPropagation()">WhatsApp</a><a class="pill call" style="padding:8px 14px;text-decoration:none" href="tel:${g.phone.replace(/\s/g,'')}" onclick="event.stopPropagation()">Call</a></div></div>`}
function today(){const mine=G.filter(g=>g.month==='Oct 2026');const c={all:mine.length,call:mine.filter(g=>g.calls===0).length,fu:mine.filter(g=>g.calls>0).length,mem:mine.filter(g=>g.status==='Member').length};
let list=mine.filter(g=>S.tile==='call'?g.calls===0:S.tile==='fu'?g.calls>0:S.tile==='mem'?g.status==='Member':true).sort((a,b)=>(a.calls-b.calls)||(b.days-a.days));
return `<div class="hdr"><div><h1>Good afternoon, David</h1><p>Wed 28 Oct · ${c.call} guests waiting for a call</p></div></div>
<div class="body"><div class="tiles">${[['call','To call',c.call],['fu','Followed up',c.fu],['mem','Members',c.mem]].map(([k,l,n])=>`<button class="tile ${S.tile===k?'on':''}" onclick="S.tile=S.tile==='${k}'?'all':'${k}';render()"><b>${n}</b><span>${l}</span></button>`).join('')}</div>
<div class="sect">${S.tile==='all'?'All my guests this month':{call:'To call',fu:'Followed up',mem:'Members'}[S.tile]}</div>${list.map(card).join('')||'<div class="empty">Nothing here yet.</div>'}</div>`}
function guests(){const chips=[['all','All'],['call','To call'],['fu','Followed up'],['mem','Members'],['team','In a team']];
let list=G.filter(g=>g.month===S.month).filter(g=>S.chip==='call'?g.calls===0:S.chip==='fu'?g.calls>0:S.chip==='mem'?g.status==='Member':S.chip==='team'?g.team:true);
return `<div class="hdr"><div><h1>My guests</h1><p>${S.month} · ${list.length} guests</p></div><button class="calbtn" onclick="S.sheet=true;render()" aria-label="Choose month">${CAL}</button></div>
<div class="body"><div class="chips">${chips.map(([k,l])=>`<button class="chip ${S.chip===k?'on':''}" onclick="S.chip='${k}';render()">${l}</button>`).join('')}</div>${list.map(card).join('')||'<div class="empty">No guests match.</div>'}</div>`}
function guest(){const g=G.find(x=>x.id===S.view);const need=g.sun>=4||(g.sun>=3&&g.wed>=2);
return `<div class="hdr round" style="flex-direction:column;align-items:stretch">${BACK('Back')}<div class="row"><div class="av" style="background:var(--gold);width:56px;height:56px;font-size:20px">${initials(g.name)}</div><div class="grow"><div style="font-size:22px;font-weight:600">${g.name}</div><div style="color:#B9C4D8;font-size:13px">${g.phone} · came ${g.month}</div></div><span class="pill ${cls[g.status]}">${g.status}</span></div></div>
<div class="body"><div class="row"><a class="btn wa" style="text-decoration:none" href="${wa(g.phone)}" target="_blank">WhatsApp</a><a class="btn call" style="text-decoration:none" href="tel:${g.phone.replace(/\s/g,'')}">Call</a></div>
<div class="card"><b>Road to membership</b><div class="mut" style="margin:2px 0 12px">4 Sundays, or 3 Sundays and 2 Wednesdays, in one month</div>
<div class="mut">Sundays ${g.sun}/4</div><div class="dots" style="margin:6px 0 12px">${[1,2,3,4].map(i=>`<div class="dot ${g.sun>=i?'on':''}">${i}</div>`).join('')}</div>
<div class="mut">Wednesdays ${g.wed}/2</div><div class="dots" style="margin-top:6px">${[1,2].map(i=>`<div class="dot ${g.wed>=i?'on':''}">${i}</div>`).join('')}</div>
<div style="margin-top:12px;font-weight:600;color:${g.status==='Member'?'#8A6A00':'var(--mut)'}">${g.status==='Member'?'★ Member':need?'Qualifies this month':'Keeps attending to qualify'}</div></div>
<div class="card"><div class="row"><b class="grow">Last feedback</b><span class="mut">${g.fbDate}</span></div><div style="margin-top:6px">${g.fb||'<span class="mut">No follow-up yet.</span>'}</div></div>
<div class="tiles" style="grid-template-columns:1fr 1fr"><div class="card"><b style="font-size:24px">${g.fu}</b><div class="mut">Follow-ups</div></div><div class="card"><b style="font-size:24px">${g.team||'—'}</b><div class="mut">Team joined</div></div></div></div>
<div class="foot"><button class="btn gold" onclick="S.log={out:'Reached',sun:false,wed:false,team:g.team,note:''};render()">Log a follow-up</button></div>`}
function logv(){const g=G.find(x=>x.id===S.view),L=S.log;
return `<div class="hdr round" style="flex-direction:column;align-items:stretch">${BACK('Cancel')}<h1>Log a follow-up</h1><p>${g.name}</p></div>
<div class="body" style="gap:18px;padding-top:18px"><div class="field"><label>How did it go?</label><div class="chips" style="flex-wrap:wrap">${['Reached','No answer','Busy','Switched off','Wrong number'].map(o=>`<button class="chip ${L.out===o?'on':''}" onclick="S.log.out='${o}';render()">${o}</button>`).join('')}</div></div>
<div class="field"><label>Feedback</label><textarea id="note" rows="3" placeholder="What did they say?" oninput="S.log.note=this.value">${L.note}</textarea></div>
${[['sun','Attended Sunday'],['wed','Attended Wednesday']].map(([k,l])=>`<div class="card row"><div class="grow"><b>${l}</b>${L[k]?'<div class="mut">Date: today</div>':''}</div><button class="sw ${L[k]?'on':''}" onclick="S.log.${k}=!S.log.${k};render()" aria-label="${l}"></button></div>`).join('')}
<div class="field"><label>Joined a team?</label><div class="chips">${['','Workforce','Evangelism'].map(t=>`<button class="chip ${L.team===t?'on':''}" onclick="S.log.team='${t}';render()">${t||'Not yet'}</button>`).join('')}</div></div></div>
<div class="foot"><button class="btn gold" onclick="saveLog()">Save follow-up</button></div>`}
function saveLog(){const g=G.find(x=>x.id===S.view),L=S.log;g.calls++;g.fu++;g.fb=L.note||g.fb;g.fbDate='28 Oct';if(L.out==='Reached'&&g.status==='New guest')g.status='Contacted';if(L.sun){g.sun++;if(g.status!=='Member')g.status='Returning'}if(L.wed){g.wed++;if(g.status!=='Member')g.status='Returning'}if(L.team)g.team=L.team;if(g.sun>=4||(g.sun>=3&&g.wed>=2))g.status='Member';S.log=null;render()}
function rank(){const r=RANK[S.rmonth];const me=r.findIndex(x=>x[0]==='David')+1;const top=r.slice(0,3);
return `<div class="hdr"><div><h1>Ranking</h1><p>How the team is doing</p></div></div><div class="body"><div class="chips">${Object.keys(RANK).map(m=>`<button class="chip ${S.rmonth===m?'on':''}" onclick="S.rmonth='${m}';render()">${m}</button>`).join('')}</div>
<div class="card" style="background:var(--navy);color:#fff;display:flex;align-items:flex-end;justify-content:center;gap:10px;padding:22px 14px 16px">${[1,0,2].map(i=>`<div style="text-align:center;flex:1"><div style="font-size:${i===0?30:22}px">${['🥇','🥈','🥉'][i]}</div><b>${top[i][0]}</b><div style="color:#B9C4D8;font-size:13px">${top[i][1]} pts</div><div style="height:${[70,48,34][i]}px;background:${i===0?'var(--gold)':'#2B4A73'};border-radius:10px 10px 0 0;margin-top:8px"></div></div>`).join('')}</div>
${r.slice(3).map((x,i)=>`<div class="card row"><b style="width:22px;color:var(--mut)">${i+4}</b><div class="av">${x[0][0]}</div><b class="grow">${x[0]}</b><span>${x[1]} pts</span></div>`).join('')}
<div class="card" style="border:2px solid var(--gold);background:#FFFAEB"><div class="row"><div class="av" style="background:var(--gold)">D</div><div class="grow"><b>You</b><div class="mut">${S.rmonth}</div></div><div style="text-align:right"><b style="font-size:24px">#${me}</b><div class="mut">${r[me-1][1]} pts</div></div></div></div>
<div class="card"><b>How points work</b>${[['First call within 3 days','+10'],['Each follow-up','+5'],['Guest attends Sunday or Wednesday','+10'],['Guest joins a team','+20'],['Guest becomes a member','+30']].map(([a,b])=>`<div class="row" style="margin-top:10px"><span class="grow">${a}</span><b>${b}</b></div>`).join('')}</div></div>`}
function me(){const mine=G.filter(g=>g.month==='Oct 2026');
return `<div class="hdr round" style="flex-direction:column;align-items:flex-start;gap:14px"><div class="row"><div class="av" style="background:var(--gold);width:60px;height:60px;font-size:24px">D</div><div><h1 style="font-size:24px">David Olanite</h1><p>davidolanite0@gmail.com</p></div></div></div>
<div class="body"><div class="tiles"><div class="card"><b style="font-size:24px">${mine.length}</b><div class="mut">Guests</div></div><div class="card"><b style="font-size:24px">${mine.filter(g=>g.calls>0).length}</b><div class="mut">Contacted</div></div><div class="card"><b style="font-size:24px;color:#8A6A00">${mine.filter(g=>g.status==='Member').length}</b><div class="mut">Members</div></div></div>
<div class="card"><div class="row"><b class="grow">Called within 3 days</b><span>${mine.filter(g=>g.calls>0).length} of ${mine.length}</span></div><div class="bar" style="margin-top:8px"><i style="width:${Math.round(100*mine.filter(g=>g.calls>0).length/mine.length)}%;background:var(--green)"></i></div></div>
<div class="card row"><b class="grow">This month's rank</b><b style="font-size:22px">#2</b></div>
<div class="card"><div class="mut">Signed in as a Worker. Guests are assigned to you automatically, and you cannot add or edit guest details.</div></div></div>`}
function render(){let h='';const inner=S.view?(S.log?logv():guest()):{today,guests,rank,me}[S.tab]();
h=inner+(S.view?'':tabs());
if(S.sheet)h+=`<div class="sheet-bg" onclick="S.sheet=false;render()"><div class="sheet" onclick="event.stopPropagation()"><h3>Choose a month</h3>${MONTHS.map(m=>`<button class="mi ${S.month===m?'on':''}" onclick="S.month='${m}';S.sheet=false;render()">${m}${S.month===m?' ✓':''}</button>`).join('')}</div></div>`;
$('#phone').innerHTML=h}
render();
