import {redirect} from 'next/navigation'
import type {ReactNode} from 'react'
import {createClient} from '@/lib/supabase/server'

export default async function AdminLayout({children}:{children:ReactNode}){
  const supabase=await createClient();
  const {data:claimsData}=await supabase.auth.getClaims();
  const claims=claimsData?.claims as Record<string,unknown>|undefined;
  const metadata=(claims?.app_metadata||{}) as Record<string,unknown>;
  const role=String(metadata.role||'');
  if(!claims?.sub||!['admin_general','staff','reviewer','operator'].includes(role))redirect('/login?next=/admin');
  const {data:aal}=await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
  if(aal?.nextLevel==='aal2'&&aal.currentLevel!=='aal2')redirect('/login/mfa?next=/admin');
  return <>{children}</>;
}

