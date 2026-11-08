import {NextResponse} from 'next/server'
import {createClient} from '@/lib/supabase/server'
export async function GET(request:Request){const {searchParams}=new URL(request.url);const q=searchParams.get('q');const category=searchParams.get('category');const supabase=await createClient();let query=supabase.from('activities').select('id,slug,title,description,category,starts_at,ends_at,location,modality,duration_hours,capacity,minimum_attendance_pct').eq('status','published').order('starts_at');if(q)query=query.or(`title.ilike.%${q}%,description.ilike.%${q}%`);if(category)query=query.eq('category',category);const {data,error}=await query;return NextResponse.json({data:data??[],error:error?.message??null},{status:error?500:200})}

