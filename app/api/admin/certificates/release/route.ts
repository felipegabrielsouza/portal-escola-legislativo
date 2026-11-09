import {NextResponse} from 'next/server'
import {getCurrentClaims,isStaffClaims} from '@/lib/auth'
import {PDFDocument,StandardFonts,rgb} from 'pdf-lib'

export async function POST(request:Request){
  const body=await request.json(); const {supabase,claims}=await getCurrentClaims()
  if(!claims?.sub||!isStaffClaims(claims))return NextResponse.json({error:'Acesso administrativo necessário.'},{status:403})
  const {data,error}=await supabase.rpc('release_certificate',{p_enrollment_id:String(body.enrollmentId),p_template_version_id:body.templateVersionId?String(body.templateVersionId):null})
  if(error)return NextResponse.json({error:'Certificado não liberado.',detail:error.message},{status:400})
  const certificate=Array.isArray(data)?data[0]:data
  if(!certificate?.id)return NextResponse.json({error:'Emissão sem identificador.'},{status:500})
  const {data:details}=await supabase.from('certificates').select('id,certificate_code,verification_name,activity_name,workload_hours,period_start,period_end,issuer,enrollment_id').eq('id',certificate.id).single()
  if(!details)return NextResponse.json({error:'Certificado emitido, mas os dados não puderam ser recuperados.'},{status:500})
  const pdf=await PDFDocument.create(); const page=pdf.addPage([842,595]); const font=await pdf.embedFont(StandardFonts.Helvetica); const bold=await pdf.embedFont(StandardFonts.HelveticaBold)
  page.drawRectangle({x:24,y:24,width:794,height:547,borderColor:rgb(0.06,0.17,0.31),borderWidth:3})
  page.drawText('ESCOLA DO LEGISLATIVO', {x:250,y:475,size:24,font:bold,color:rgb(0.06,0.17,0.31)})
  page.drawText('Câmara Municipal de Mococa', {x:313,y:445,size:14,font,color:rgb(0.23,0.28,0.34)})
  page.drawText('CERTIFICADO', {x:326,y:365,size:30,font:bold,color:rgb(0.83,0.57,0.08)})
  page.drawText(`Certificamos que ${details.verification_name}`, {x:150,y:300,size:18,font})
  page.drawText(`participou da atividade ${details.activity_name}`, {x:150,y:270,size:18,font})
  page.drawText(`com carga horária de ${details.workload_hours} horas.`, {x:150,y:240,size:18,font})
  page.drawText(`Código de verificação: ${details.certificate_code}`, {x:150,y:170,size:12,font:bold})
  page.drawText(details.issuer, {x:150,y:145,size:11,font})
  const bytes=await pdf.save(); const path=`certificates/${details.id}.pdf`
  const upload=await supabase.storage.from('portal-private').upload(path,Buffer.from(bytes),{contentType:'application/pdf',upsert:true})
  if(upload.error){await supabase.from('certificate_issuance_jobs').update({status:'retryable',error_message:upload.error.message,updated_at:new Date().toISOString()}).eq('certificate_id',details.id);return NextResponse.json({error:'Certificado emitido, mas o PDF não foi armazenado.',detail:upload.error.message},{status:503})}
  const {error:updateError}=await supabase.from('certificates').update({pdf_path:path}).eq('id',details.id)
  if(updateError)return NextResponse.json({error:'PDF armazenado, mas o vínculo do certificado falhou.',detail:updateError.message},{status:503})
  const {data:enrollment}=await supabase.from('enrollments').select('participant_id,guest_email,guest_name').eq('id',details.enrollment_id).single()
  if(enrollment?.participant_id)await supabase.from('notifications').insert({recipient_id:enrollment.participant_id,title:'Certificado liberado',body:`Seu certificado de ${details.activity_name} está disponível.`,href:`/api/certificates/${details.id}/download`})
  return NextResponse.json({certificate:{...certificate,pdf_path:path},downloadUrl:`/api/certificates/${details.id}/download`},{status:201})
}

