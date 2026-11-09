import {Shell} from '@/app/components/Shell'
import PrivacyForm from './PrivacyForm'
export default function Privacidade(){return <Shell title="Privacidade"><h1>Privacidade e direitos dos titulares</h1><p>O portal coleta somente dados necessários para inscrições, autenticação, frequência, certificados e atendimento. O titular pode solicitar acesso, correção ou exclusão, sujeito à verificação de identidade, retenção legal e análise do Encarregado de Dados.</p><div className="card narrow"><h2>Registrar solicitação</h2><p>A equipe fará a conferência de identidade e responderá conforme a base legal e os prazos institucionais.</p><PrivacyForm/></div></Shell>}

