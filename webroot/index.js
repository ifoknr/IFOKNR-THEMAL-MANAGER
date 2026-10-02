import { exec, toast } from './kernelsu.js'
import './md3.js'

document.querySelector('.preload-hidden')?.classList.remove('preload-hidden')

const MODDIR = '/data/adb/modules/thermal_mode_manager'
const CONFIG_FILE = `${MODDIR}/config.sh`

const MODES = {
    '0': { id: 'balanced', name: 'Balanced', icon: '⚖️' },
    '1': { id: 'battery', name: 'Battery', icon: '🔋' },
    '6': { id: 'performance', name: 'Performance', icon: '⚡' },
    '19': { id: 'gaming', name: 'Gaming', icon: '🎮' }
}

const NAME_TO_KEY = {
    'balanced': '0',
    'battery': '1',
    'performance': '6',
    'gaming': '19'
}

async function updateStatus() {
    // 1. فحص دعم العتاد لميديا تيك
    const checkSoc = await exec(`[ -d /sys/class/thermal ] && echo "1" || echo "0"`)
    const available = checkSoc.stdout.trim() === '1'
    
    const interfaceEl = document.getElementById('interface-status')
    if (interfaceEl) {
        interfaceEl.textContent = available ? 'Dimensity 9300+' : 'Not Available'
        interfaceEl.className = `status-badge ${available ? 'active' : 'inactive'}`
    }

    // 2. فحص تشغيل خدمة الخلفية
    const pidCheck = await exec(`cat ${MODDIR}/service.pid 2>/dev/null`)
    const pid = pidCheck.stdout.trim()
    let running = false
    
    if (pid) {
        const psCheck = await exec(`kill -0 ${pid} 2>/dev/null && echo "1" || echo "0"`)
        running = psCheck.stdout.trim() === '1'
    }
    
    const serviceEl = document.getElementById('service-status')
    if (serviceEl) {
        serviceEl.textContent = running ? 'Running' : 'Stopped'
        serviceEl.className = `status-badge ${running ? 'active' : 'inactive'}`
    }

    // 3. قراءة النمط النشط وتحديث البطاقة
    let rawMode = (await exec(`cat ${MODDIR}/mode 2>/dev/null`)).stdout.trim().toLowerCase()
    if (!rawMode) {
        rawMode = (await exec(`cat ${MODDIR}/current_mode 2>/dev/null`)).stdout.trim().toLowerCase()
    }

    let modeKey = '0'
    if (MODES[rawMode]) {
        modeKey = rawMode
    } else if (NAME_TO_KEY[rawMode]) {
        modeKey = NAME_TO_KEY[rawMode]
    }

    const info = MODES[modeKey] || MODES['0']
    
    const iconEl = document.getElementById('current-mode-icon')
    const nameEl = document.getElementById('current-mode-name')
    if (iconEl) iconEl.textContent = info.icon
    if (nameEl) nameEl.textContent = info.name
    
    document.querySelectorAll('.mode-card').forEach(card => {
        card.classList.toggle('active', card.dataset.mode === modeKey)
    })
}

// التبديل عند النقر
document.querySelectorAll('.mode-card').forEach(card => {
    card.addEventListener('click', async () => {
        const modeKey = card.dataset.mode
        const info = MODES[modeKey]
        if (!info) return
        
        await exec(`echo "${info.id}" > ${MODDIR}/mode`)
        await exec(`echo "${modeKey}" > ${MODDIR}/current_mode`)
        await exec(`sh ${MODDIR}/update-desc.sh "${info.id}" 2>/dev/null`)
        
        toast(`🎮 ${info.name} mode`)
        updateStatus()
    })
})

// أزرار التحكم
document.getElementById('restart-btn')?.addEventListener('click', async () => {
    const pidCheck = await exec(`cat ${MODDIR}/service.pid 2>/dev/null`)
    if (pidCheck.stdout.trim()) {
        await exec(`kill -9 ${pidCheck.stdout.trim()} 2>/dev/null`)
    }
    await exec(`sh ${MODDIR}/service.sh &`)
    toast('Service restarted')
    setTimeout(updateStatus, 800)
})

document.getElementById('refresh-btn')?.addEventListener('click', () => {
    updateStatus()
    toast('Refreshed')
})

document.getElementById('github-link')?.addEventListener('click', async (e) => {
    e.preventDefault()
    await exec('am start -a android.intent.action.VIEW -d "https://github.com/ifoknr/Thermal-Manager-Samsung-Galaxy-Tab-S10-Ultra"')
})

// مزامنة توفير الطاقة التلقائي
async function loadAutoBatterySaver() {
    const autoFile = await exec(`cat ${MODDIR}/auto_battery 2>/dev/null`)
    const enabled = autoFile.stdout.trim() === '1'
    const switchEl = document.getElementById('auto_battery_saver')
    if (switchEl) switchEl.selected = enabled
}

document.getElementById('auto_battery_saver')?.addEventListener('change', async (e) => {
    const enabled = e.target.selected ? '1' : '0'
    await exec(`echo "${enabled}" > ${MODDIR}/auto_battery`)
    toast(enabled === '1' ? '✅ Auto battery saver enabled' : '🔋 Auto battery saver disabled')
})

// بدء التشغيل والمراقبة
updateStatus()
loadAutoBatterySaver()
setInterval(updateStatus, 4000)

window.addEventListener('back', () => {
    window.webui?.exit()
})