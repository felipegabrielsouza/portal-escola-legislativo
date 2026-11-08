import {describe,expect,it} from 'vitest'
import {anonymizedEvaluationKey,canCancelEnrollment,canReopenComplementation,isCertificateEligible,isValidCpf,normalizeCpf,validateRegistration,weightedAttendance} from '../lib/domain'

describe('regras do portal',()=>{
  it('normaliza e valida CPF',()=>{expect(normalizeCpf('529.982.247-25')).toBe('52998224725');expect(isValidCpf('529.982.247-25')).toBe(true);expect(isValidCpf('111.111.111-11')).toBe(false)})
  it('valida inscrição híbrida sem data de nascimento',()=>{const errors=validateRegistration({name:'Ana Silva',email:'ana@example.com',cpf:'529.982.247-25',phone:'16999999999',city:'Mococa',state:'sp'});expect(errors).toEqual([])})
  it('calcula presença ponderada e elegibilidade',()=>{expect(weightedAttendance([{hours:2,hoursPresent:2},{hours:4,hoursPresent:3}])).toBe(83.33);expect(isCertificateEligible(83.33,75,true)).toBe(true);expect(isCertificateEligible(83.33,75,false)).toBe(false)})
  it('protege cancelamento e reabertura por justificativa',()=>{const future=new Date(Date.now()+86400000);expect(canCancelEnrollment(future)).toBe(true);expect(canReopenComplementation('expired','justificativa formal com base suficiente')).toBe(true);expect(canReopenComplementation('expired','curto')).toBe(false)})
  it('gera chave não identificável para avaliação',()=>{expect(anonymizedEvaluationKey('form','enrollment')).toBe(anonymizedEvaluationKey('form','enrollment'));expect(anonymizedEvaluationKey('form','enrollment')).not.toContain('enrollment')})
})

