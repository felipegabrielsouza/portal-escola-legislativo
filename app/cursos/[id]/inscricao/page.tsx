import EnrollmentForm from './EnrollmentForm'
export default async function Inscricao({params}:{params:Promise<{id:string}>}){const {id}=await params;return <EnrollmentForm activityId={id}/>} 

