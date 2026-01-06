import { createClient } from "npm:@supabase/supabase-js@2"
import { JWT } from "npm:google-auth-library@9.0.0"

Deno.serve(async (req) => {
  try {
    const { user_id, title, body, data } = await req.json()
    
    const saVar = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')
    if (!saVar) throw new Error('FIREBASE_SERVICE_ACCOUNT is not set')
    const serviceAccount = JSON.parse(saVar)
    
    // --- 秘密鍵の「究極の」再フォーマットロジック ---
    let rawKey = serviceAccount.private_key
    
    // 1. ヘッダー、フッター、改行、空白をすべて取り除き、純粋なBase64文字列だけにする
    const base64Body = rawKey
      .replace('-----BEGIN PRIVATE KEY-----', '')
      .replace('-----END PRIVATE KEY-----', '')
      .replace(/\s/g, '') // 改行やスペースをすべて削除
      .replace(/\\n/g, '') // 文字としての \n も削除

    // 2. 64文字ごとに改行を入れ直して、正しいPEM形式に組み立て直す
    const matches = base64Body.match(/.{1,64}/g)
    if (!matches) throw new Error('Invalid private key body')
    
    const formattedKey = [
      '-----BEGIN PRIVATE KEY-----',
      ...matches,
      '-----END PRIVATE KEY-----',
      '' // 最後に空行を入れる
    ].join('\n')
    // ------------------------------------------

    const client = new JWT({
      email: serviceAccount.client_email,
      key: formattedKey,
      scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
    })

    const gToken = await client.getAccessToken()
    const accessToken = gToken.token
    if (!accessToken) throw new Error('Failed to generate access token')

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )
    
    const { data: tokens, error: dbError } = await supabase
      .from('device_tokens')
      .select('fcm_token')
      .eq('user_id', user_id)
    
    if (dbError) throw dbError
    if (!tokens || tokens.length === 0) {
      return new Response(JSON.stringify({ error: 'No tokens found' }), { status: 404 })
    }
    
    const projectId = serviceAccount.project_id
    for (const token of tokens) {
      await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${accessToken}`
        },
        body: JSON.stringify({
          message: {
            token: token.fcm_token,
            notification: { title, body },
            data: data || {}
          }
        })
      })
    }
    
    return new Response(JSON.stringify({ success: true }), { status: 200 })

  } catch (error: any) {
    console.error('Handled Error:', error.message)
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }
})