import pathlib,json,sys,time
p=pathlib.Path(__file__).parent; n=sys.argv[1]; b=json.loads((p/'run.json').read_text()); start=json.loads((p/f'cycle-{n}-before-close.json').read_text())['elapsed_ms']; deadline=time.monotonic()+40
while True:
 rows=[json.loads(l) for l in pathlib.Path(b['log']).read_text().splitlines()]; z=next((r for r in rows if r['event']=='sample' and r['elapsed_ms']>start and r['visible_main_capable_windows']==1),None)
 samples={str(t):next((r for r in rows if r['event']=='sample' and r['elapsed_ms']>=z['elapsed_ms']+t*1000),None) for t in (0,5,20)} if z else {}
 if samples.get('20'): break
 if time.monotonic()>deadline: raise RuntimeError('20 s post-close sample unavailable')
 time.sleep(0.5)
(p/f'cycle-{n}-after-close.json').write_text(json.dumps(samples,indent=2)+'\n'); print(json.dumps(samples))
