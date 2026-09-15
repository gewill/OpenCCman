import datetime, hashlib, json, pathlib, plistlib, statistics, subprocess, sys
mode=sys.argv[1]
configurations={
 's2t':('Traditional Chinese','OpenCC Standard','Not convert'),
 's2tw':('Traditional Chinese','Taiwan Standard','Not convert'),
 's2twp':('Traditional Chinese','Taiwan Standard','Taiwan Idiom'),
 's2hk':('Traditional Chinese','HongKong Standard','Not convert'),
 't2s':('Simplified Chinese','HongKong Standard','Taiwan Idiom'),
 'legacy-s2t-tw-idiom':('Traditional Chinese','OpenCC Standard','Taiwan Idiom'),
 'legacy-s2hk-tw-idiom':('Traditional Chinese','HongKong Standard','Taiwan Idiom'),
}
root=pathlib.Path('.build/services-probe'); corpus=root/'corpus-v1'
manifest=json.loads((corpus/'manifest.json').read_text())
cases=[c for c in manifest['cases'] if c['mode']==mode]
assert len(cases)==8
prefs=plistlib.loads(subprocess.check_output(['defaults','export','org.gewill.OpenCCman.ServicesValidation','-']))
observed=tuple(prefs.get(k,d) for k,d in zip(('targetOptions','variantOptions','regionOptions'),configurations['s2t']))
assert observed==configurations[mode],(observed,configurations[mode])
provider=pathlib.Path.home()/'Applications/OpenCCman Services Probe eab5003.app/Contents/MacOS/OpenCCman'
assert hashlib.sha256(provider.read_bytes()).hexdigest()=='11b54d162172123fbf742441f7188d74176df9360b8e53ad7bcfffd61b526e21'
command=subprocess.check_output(['ps','-p','80200','-o','command='],text=True).strip()
assert command.startswith(str(provider)+' ')
for c in cases:
 for key in ('input','expected'):
  assert hashlib.sha256((corpus/c[key]).read_bytes()).hexdigest()==c[key+'SHA256']
out=root/'configuration-series'/mode; out.mkdir(exist_ok=False)
(out/'context.json').write_text(json.dumps({'mode':mode,'uiSelectedConfiguration':observed,'providerPID':80200,'sourceSHA':'eab5003bfdd938f08b936826225d7ab482d6f703','startUTC':datetime.datetime.now(datetime.timezone.utc).isoformat(),'providerState':'already launched, one window open, configuration sheet dismissed','sequence':'one 1 KiB priming call then eight cases x five consecutive calls; no artificial waits','corpusManifestSHA256':hashlib.sha256((corpus/'manifest.json').read_bytes()).hexdigest()},indent=2)+'\n')
probe='/tmp/openccman-services-wait-probe'
def run(c,name,count):
 with (out/(name+'.jsonl')).open('x') as log, (out/(name+'.stderr')).open('x') as err:
  result=subprocess.run([probe,'OpenCCman Probe eab5003 Convert',str(corpus/c['input']),str(corpus/c['expected']),str(count)],stdout=log,stderr=err)
 assert result.returncode==0,(name,result.returncode)
 records=[json.loads(l) for l in (out/(name+'.jsonl')).read_text().splitlines()]
 assert records[-1]=={'event':'run_completed','samples':count}
 values=[r for r in records if r['event']=='sample_completed']
 assert len(values)==count and all(r['service_succeeded'] and r['output_matches_expected'] for r in values)
 assert all(r['output_sha256']==c['expectedSHA256'] for r in values)
 return [r['service_call_ms'] for r in values]
run(cases[0],'priming',1)
summary=[]
for c in cases:
 name=f"{c['shape']}-{c['inputBytes']}"
 values=run(c,name,5)
 row={'mode':mode,'shape':c['shape'],'inputBytes':c['inputBytes'],'samples':len(values),'medianMS':statistics.median(values),'minMS':min(values),'maxMS':max(values)}
 summary.append(row); print(json.dumps(row),flush=True)
(out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
