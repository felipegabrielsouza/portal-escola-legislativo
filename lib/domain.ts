export type RegistrationInput={name:string;email:string;cpf:string;phone:string;city:string;state:string;institution?:string;jobTitle?:string}
export function normalizeCpf(value:string){return value.replace(/\D/g,'')}
export function isValidCpf(value:string){const cpf=normalizeCpf(value);if(cpf.length!==11||/^([0-9])\1+$/.test(cpf))return false;let sum=0;for(let i=0;i<9;i++)sum+=Number(cpf[i])*(10-i);let d1=(sum*10)%11;if(d1===10)d1=0;if(d1!==Number(cpf[9]))return false;sum=0;for(let i=0;i<10;i++)sum+=Number(cpf[i])*(11-i);let d2=(sum*10)%11;if(d2===10)d2=0;return d2===Number(cpf[10])}
export function validateRegistration(input:RegistrationInput){const errors:string[]=[];if(!input.name.trim())errors.push('Nome é obrigatório.');if(!/^\S+@\S+\.\S+$/.test(input.email))errors.push('E-mail inválido.');if(!isValidCpf(input.cpf))errors.push('CPF inválido.');if(!input.phone.trim())errors.push('Telefone é obrigatório.');if(!input.city.trim()||!input.state.trim())errors.push('Cidade e UF são obrigatórios.');return errors}
export function weightedAttendance(sessions:Array<{hours:number;hoursPresent:number}>){const total=sessions.reduce((s,x)=>s+x.hours,0);if(total===0)return 0;return Math.round((sessions.reduce((s,x)=>s+Math.min(Math.max(x.hoursPresent,0),x.hours),0)/total)*10000)/100}
export function isCertificateEligible(attendancePct:number,minimumPct:number,manuallyReleased:boolean){return manuallyReleased&&attendancePct>=minimumPct}
export function canCancelEnrollment(deadlineAt:Date,now=new Date(),administrativeException=false){return administrativeException||now.getTime()<=deadlineAt.getTime()}
export function canReopenComplementation(status:string,justification:string){return status==='expired'&&justification.trim().length>=20}
export function anonymizedEvaluationKey(formId:string,enrollmentId:string){let hash=0;for(const c of `${formId}:${enrollmentId}`)hash=(hash*31+c.charCodeAt(0))|0;return Math.abs(hash).toString(36)}

