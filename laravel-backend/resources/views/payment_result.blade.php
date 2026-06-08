<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{ $title }}</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;600;700&display=swap" rel="stylesheet">
    <style>
        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }
        body {
            font-family: 'Outfit', sans-serif;
            background-color: #0F111A;
            color: #FFFFFF;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            padding: 24px;
            overflow: hidden;
        }
        
        /* Subtle background glowing spots */
        .bg-glow {
            position: absolute;
            width: 300px;
            height: 300px;
            border-radius: 50%;
            filter: blur(120px);
            z-index: 1;
            opacity: 0.15;
            pointer-events: none;
        }
        .bg-glow-1 {
            top: -50px;
            left: -50px;
            background: #6366F1;
        }
        .bg-glow-2 {
            bottom: -50px;
            right: -50px;
            background: {{ $status === 'success' ? '#10B981' : '#F87171' }};
        }

        .container {
            position: relative;
            z-index: 10;
            width: 100%;
            max-width: 420px;
            background: rgba(22, 25, 37, 0.7);
            backdrop-filter: blur(16px);
            -webkit-backdrop-filter: blur(16px);
            border: 1px solid rgba(255, 255, 255, 0.08);
            border-radius: 24px;
            padding: 40px 32px;
            text-align: center;
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.3);
            animation: slideUp 0.6s cubic-bezier(0.16, 1, 0.3, 1) forwards;
        }

        @keyframes slideUp {
            from {
                opacity: 0;
                transform: translateY(30px);
            }
            to {
                opacity: 1;
                transform: translateY(0);
            }
        }

        /* Animated Icon */
        .icon-wrapper {
            width: 80px;
            height: 80px;
            margin: 0 auto 28px;
            position: relative;
            display: flex;
            align-items: center;
            justify-content: center;
        }

        .icon-bg {
            position: absolute;
            inset: 0;
            border-radius: 50%;
            background: {{ $status === 'success' ? 'rgba(16, 185, 129, 0.1)' : 'rgba(248, 113, 113, 0.1)' }};
            border: 1px solid {{ $status === 'success' ? 'rgba(16, 185, 129, 0.2)' : 'rgba(248, 113, 113, 0.2)' }};
            animation: pulse 2s infinite;
        }

        @keyframes pulse {
            0% {
                transform: scale(1);
                opacity: 1;
            }
            50% {
                transform: scale(1.12);
                opacity: 0.8;
            }
            100% {
                transform: scale(1);
                opacity: 1;
            }
        }

        .icon-svg {
            width: 48px;
            height: 48px;
            color: {{ $status === 'success' ? '#34D399' : '#F87171' }};
            z-index: 2;
        }

        /* Stroke animations */
        .checkmark-path {
            stroke-dasharray: 100;
            stroke-dashoffset: 100;
            animation: drawStroke 0.8s 0.2s cubic-bezier(0.16, 1, 0.3, 1) forwards;
        }
        
        .cross-path-1 {
            stroke-dasharray: 100;
            stroke-dashoffset: 100;
            animation: drawStroke 0.4s 0.2s cubic-bezier(0.16, 1, 0.3, 1) forwards;
        }

        .cross-path-2 {
            stroke-dasharray: 100;
            stroke-dashoffset: 100;
            animation: drawStroke 0.4s 0.4s cubic-bezier(0.16, 1, 0.3, 1) forwards;
        }

        @keyframes drawStroke {
            to {
                stroke-dashoffset: 0;
            }
        }

        h1 {
            font-size: 24px;
            font-weight: 700;
            letter-spacing: -0.5px;
            margin-bottom: 12px;
            color: #FFFFFF;
        }

        p {
            font-size: 15px;
            color: #A0AEC0;
            line-height: 1.6;
            margin-bottom: 32px;
            font-weight: 300;
        }

        .divider {
            height: 1px;
            background: rgba(255, 255, 255, 0.08);
            margin-bottom: 24px;
        }

        .info-row {
            display: flex;
            justify-content: space-between;
            align-items: center;
            font-size: 13px;
            margin-bottom: 12px;
        }

        .info-label {
            color: #718096;
            font-weight: 400;
        }

        .info-value {
            color: #E2E8F0;
            font-weight: 600;
            word-break: break-all;
            max-width: 65%;
            text-align: right;
        }

        .status-badge {
            display: inline-block;
            padding: 4px 12px;
            border-radius: 12px;
            font-size: 11px;
            font-weight: 700;
            letter-spacing: 0.5px;
            text-transform: uppercase;
            background: {{ $status === 'success' ? 'rgba(52, 211, 153, 0.15)' : 'rgba(248, 113, 113, 0.15)' }};
            color: {{ $status === 'success' ? '#34D399' : '#F87171' }};
            border: 1px solid {{ $status === 'success' ? 'rgba(52, 211, 153, 0.3)' : 'rgba(248, 113, 113, 0.3)' }};
        }

        /* Auto redirecting hint */
        .redirect-hint {
            font-size: 12px;
            color: #4A5568;
            margin-top: 32px;
            font-style: italic;
        }
    </style>
</head>
<body>
    <div class="bg-glow bg-glow-1"></div>
    <div class="bg-glow bg-glow-2"></div>

    <div class="container">
        <div class="icon-wrapper">
            <div class="icon-bg"></div>
            @if ($status === 'success')
                <svg class="icon-svg" fill="none" stroke="currentColor" stroke-width="3" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                    <path class="checkmark-path" stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7"></path>
                </svg>
            @else
                <svg class="icon-svg" fill="none" stroke="currentColor" stroke-width="3" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                    <path class="cross-path-1" stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6"></path>
                    <path class="cross-path-2" stroke-linecap="round" stroke-linejoin="round" d="M6 6l12 12"></path>
                </svg>
            @endif
        </div>

        <h1>{{ $title }}</h1>
        <p>{{ $message }}</p>

        <div class="divider"></div>

        <div class="info-row">
            <span class="info-label">Reference ID</span>
            <span class="info-value">{{ $referenceId ?? 'N/A' }}</span>
        </div>

        <div class="info-row">
            <span class="info-label">Status</span>
            <span class="status-badge">{{ $status === 'success' ? 'Authorized' : 'Failed' }}</span>
        </div>

        <p class="redirect-hint">Redirecting you back to the application...</p>
    </div>
</body>
</html>
