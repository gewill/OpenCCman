import pathlib,json,time,sys
p=pathlib.Path(sys.argv[1]); visible=int(sys.argv[2]); filename=sys.argv[3]; b=json.loads((p/'run.json').read_text()); start=json.loads((p/('before-close.json' if visible else 'closed-second.json')).read_text()); start=start['elapsed'] if visible else start['20']['elapsed']; deadline=time.monotonic()+40
while True:
 rows=[json.loads(l) for l in pathlib.Path(b['log']).read_text().splitlines()]; z=next((r for r in rows if r['event']=='sample' and r['elapsed']>start and r['visible']==visible),None); samples={str(t):next((r for r in rows if r['event']=='sample' and r['elapsed']>=z['elapsed']+t),None) for t in (0,5,20)} if z else {}
 if samples.get('20'): break
 if time.monotonic()>deadline: raise RuntimeError('post-close sample unavailable')
 time.sleep(.5)
(p/filename).write_text(json.dumps(samples,indent=2)+'\n'); print(samples)
