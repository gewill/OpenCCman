"""Shared measurement schema and provenance checks (no application side effects)."""
import hashlib

TIMINGS = ('process_cpu_ms', 'process_start_to_root_layout_ms', 'app_init_to_root_layout_ms',
           'model_completion_ms', 'result_layout_flush_ms', 'read_decode_ms', 'source_layout_flush_ms')
PROTOCOL = 2


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_hashes(source):
    return {str(p.relative_to(source)): sha256(p) for p in sorted(source.rglob('*'))
            if p.is_file() and p.suffix in ('.swift', '.pbxproj', '.py')}


def artifact_hashes(app):
    if not app.is_dir():
        raise ValueError('Missing built app')
    return {str(p.relative_to(app)): sha256(p) for p in sorted(app.rglob('*')) if p.is_file()}


def validate_pins(metadata):
    revisions = metadata.get('resolved_checkout_revisions')
    if not revisions:
        raise ValueError('Missing verified dependency checkouts')
    pins = metadata['pins']['pins']
    if len({p['identity'] for p in pins}) != len(pins):
        raise ValueError('Duplicate dependency pins')
    for pin in pins:
        if revisions.get(pin['identity']) != pin['state']['revision']:
            raise ValueError('Dependency checkout does not match pin: ' + pin['identity'])
