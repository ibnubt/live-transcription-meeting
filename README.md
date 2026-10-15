# Live Transcription

Panel melayang untuk meeting berbahasa Inggris:
- transkrip langsung suara mereka (audio sistem) dan suara Anda (mic),
- saran jawaban singkat dari dokumen Anda (CV, dll.) dengan gaya Anda,
- tidak ikut tertangkap saat share screen atau rekam layar.

Transkripsi berjalan on-device (Apple Speech, gratis, offline). Jawaban disusun oleh Qwen3.8-27B aicon; kalau 1,5 detik belum ada respons, Grok di Tokenku ikut jalan dan yang menjawab duluan dipakai.

## Setup (sekali)

```bash
cp .env.example .env          # isi MY_NAME dan API key LLM (LLM1_KEY, LLM2_KEY)
cp gaya.example.md gaya.md    # isi gaya & contoh jawaban Anda
mkdir -p dokumen              # taruh CV/dokumen Anda di sini
./build.sh                    # butuh macOS 26 + Xcode Command Line Tools
```

LLM bisa endpoint apa saja yang kompatibel OpenAI (Tokenku, OpenRouter, Ollama lokal, dll.). Ubah `LLM1_*`/`LLM2_*` di `.env`. `.env`, `gaya.md`, `dokumen/`, dan `transkrip/` tidak ikut di-commit.

## Pakai

1. Buka `build/Live Transcription.app`. Tidak ada ikon di Dock; kontrolnya lewat panel dan ikon 💬 di menu bar.
2. Izinkan Mikrofon, Speech Recognition, dan **System Audio Recording** (suara lawan bicara). Akses layar tidak diperlukan. Kalau indikator biru di kiri atas diam saat ada suara, buka System Settings → Privacy & Security → Screen & System Audio Recording → bagian **System Audio Recording Only**, nyalakan Live Transcription, lalu buka ulang app.
3. Saat meeting, setiap mereka selesai bicara (jeda 1 detik), saran jawaban muncul di kartu atas:
   - jawaban bahasa Inggris untuk diucapkan,
   - arti pertanyaannya dalam bahasa Indonesia,
   - tanda ⚠ kalau jawaban memuat hal yang tidak ada di dokumen.

| Tombol | Fungsi |
|---|---|
| ⌃⌥J | Jawab sekarang (ucapan terakhir mereka) |
| ⌃⌥H | Sembunyikan / tampilkan panel |
| ⌃⌥A | Auto-jawab hidup / mati |
| Kolom bawah | Ketik pertanyaan sendiri kalau transkripnya meleset |

Indikator di kiri atas: biru = suara mereka, kuning = mic Anda. Gunakan headphone supaya mic tidak menangkap suara mereka dari speaker. Kalau tetap tertangkap, ada filter yang membuang ucapan yang sama.

## Supaya jawaban sesuai gaya Anda

- `dokumen/`: taruh CV dan bahan lain (PDF, DOCX, MD, TXT).
- `gaya.md`: aturan gaya dan **3–5 contoh jawaban asli Anda**. Ini paling berpengaruh.
- `transkrip/`: setiap sesi disimpan otomatis. Ucapan Anda dari sesi sebelumnya ikut dipakai sebagai contoh cara bicara.
- Setelah mengubah file, pilih menu ⋯ → **Muat ulang dokumen & gaya**. Tidak perlu restart.

Panjang jawaban, model, dan jeda auto diatur di `.env` (lihat `.env.example`).

## Share screen

- Paling aman: share **jendela atau tab tertentu**, bukan Entire Screen.
- Zoom: Settings → Share Screen → Advanced → Screen capture mode → **Capture with window filtering**. Mode "Auto" pernah dilaporkan membuat jendela tersembunyi berkedip.
- Sebelum meeting penting, uji dulu: share layar ke akun atau perangkat kedua, lalu pastikan panelnya tidak terlihat.

## Build ulang

```bash
./build.sh
```

Setelah build ulang, macOS menganggapnya app baru, jadi izin harus diberikan lagi. Untuk uji tanpa GUI:

```bash
"build/Live Transcription.app/Contents/MacOS/LiveTranscription" --test-ask "Tell me about yourself"
"build/Live Transcription.app/Contents/MacOS/LiveTranscription" --test-file rekaman.wav
```
