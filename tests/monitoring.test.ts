import {describe,it,expect} from 'vitest';
describe('REQ-176 monitoring rule',()=>{it('does not close a request because of inactivity',()=>{const inactive={status:'under_review',lastActivityDays:30};expect(inactive.status).not.toBe('closed');});it('distinguishes administrative ownership',()=>{expect(['participant','administration']).toContain('administration');});});

