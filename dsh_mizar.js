/**
 * DSH-Mizar Pro 通用解锁脚本 (兼容 Quantumult X & Loon)
 * 作用：拦截 /me, /login, /apple, /register 等接口，注入付费会员状态
 */

const isQuanX = typeof $task !== "undefined";
const isLoon = typeof $loon !== "undefined" || (typeof $done !== "undefined" && !isQuanX);

let body = $response.body;

if (body) {
    try {
        let obj = JSON.parse(body);
        
        // 定位 user 对象（支持直接返回 user 或嵌套在根对象中）
        let user = obj.user || (obj.id && obj.plan ? obj : null);
        
        if (user) {
            user.plan = "paid";
            user.paidUntil = 4070908800000;         // 2099 年
            user.grantedPaidUntil = 4070908800000;
            user.paidSources = ["invite", "appstore"];
            user.appStore = {
                productId: "me.shirazu.dshmizar.paid.monthly",
                environment: "Production",
                autoRenew: true,
                paidUntil: 4070908800000,
                revokedAt: null
            };
        }
        
        let newBody = JSON.stringify(obj);
        
        if (isQuanX) {
            $done({ body: newBody });
        } else {
            $done({ body: newBody });
        }
    } catch (e) {
        $done({});
    }
} else {
    $done({});
}
