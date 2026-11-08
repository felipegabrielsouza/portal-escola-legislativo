import {redirect} from 'next/navigation'
import {createClient} from '@/lib/supabase/server'

export const STAFF_ROLES=['admin_general','school_team','staff','reviewer','operator'] as const
export type StaffRole=typeof STAFF_ROLES[number]

export async function getCurrentClaims(){
  const supabase=await createClient();
  const {data}=await supabase.auth.getClaims();
  return {supabase,claims:(data?.claims||null) as Record<string,unknown>|null}
}

export function roleFromClaims(claims:Record<string,unknown>|null){
  return String((((claims?.app_metadata||{}) as Record<string,unknown>).role)||'')
}

export function isStaffClaims(claims:Record<string,unknown>|null){return STAFF_ROLES.includes(roleFromClaims(claims) as StaffRole)}

export async function requireStaffApi(){
  const result=await getCurrentClaims();
  if(!result.claims?.sub||!isStaffClaims(result.claims))return {ok:false as const,...result,status:403 as const}
  return {ok:true as const,...result,userId:String(result.claims.sub),role:roleFromClaims(result.claims)}
}

export async function requireStaffPage(){
  const result=await getCurrentClaims();
  if(!result.claims?.sub||!isStaffClaims(result.claims))redirect('/login?next=/admin');
  return {supabase:result.supabase,userId:String(result.claims.sub),role:roleFromClaims(result.claims)}
}

