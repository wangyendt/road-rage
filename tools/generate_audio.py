#!/usr/bin/env python3
"""Create original, deterministic synthesis. Requires NumPy only to regenerate assets."""
from pathlib import Path
import wave
import numpy as np
SR = 22050
OUT = Path(__file__).resolve().parents[1] / 'assets' / 'audio'
OUT.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(2409)
def save(name, audio, peak=.85):
    audio = np.asarray(audio)
    audio = np.tanh(audio)
    audio *= peak / max(.01, np.max(np.abs(audio)))
    with wave.open(str(OUT / (name + '.wav')), 'wb') as f:
        f.setnchannels(1 if audio.ndim == 1 else 2)
        f.setsampwidth(2); f.setframerate(SR)
        f.writeframes((audio * 32767).astype('<i2').tobytes())
def time(seconds): return np.arange(int(SR*seconds))/SR
# Smooth periodic engine, deliberately low-passed rather than an abrasive square wave.
t=time(1)
engine=sum(np.sin(2*np.pi*60*n*t + .16*np.sin(2*np.pi*6*t))/(n**1.35) for n in range(1,9))
engine *= .74+.16*np.sin(2*np.pi*30*t)
save('engine',engine,.65)
t=time(.42)
noise=rng.normal(0,1,len(t))
low=np.sin(2*np.pi*(110*t-80*t*t))*np.exp(-t*12)
crack=noise*np.exp(-t*34)*.7
save('hit', low+crack)
t=time(.95)
noise=rng.normal(0,1,len(t)); noise=np.convolve(noise,np.ones(5)/5,mode='same')
save('crash',np.sin(2*np.pi*(65*t-20*t*t))*np.exp(-t*6)+noise*np.exp(-t*5)*1.1)
t=time(.25)
save('swing',rng.normal(0,.7,len(t))*np.sin(np.pi*t/.25)**2*np.exp(-t*8),.48)
t=time(.85)
save('nitro',np.sin(2*np.pi*(95*t+250*t*t))*np.exp(-t*5)*.3+np.convolve(rng.normal(0,.8,len(t)),np.ones(7)/7,'same')*np.sin(np.pi*t/.85)**.5,.65)
t=time(.12)
save('click',np.sin(2*np.pi*900*t)*np.exp(-t*45),.45)
t=time(.30)
save('count',np.sin(2*np.pi*660*t)*np.minimum(t*90,1)*np.exp(-t*14),.6)
t=time(.65)
save('go',np.sin(2*np.pi*990*t)*np.minimum(t*90,1)*np.exp(-t*7),.6)
t=time(.60)
f=np.where(t<.12,660,np.where(t<.24,880,1320))
save('pickup',np.sin(2*np.pi*np.cumsum(f)/SR)*np.minimum(t*70,1)*np.exp(-t*5),.48)
t=time(2.0)
y=np.zeros(len(t))
for i,note in enumerate([57,60,64,69]):
    local=np.maximum(t-i*.15,0)
    y+=(t>=i*.15)*np.sin(2*np.pi*440*2**((note-69)/12)*local)*np.minimum(local*45,1)*np.exp(-local*2.5)*.35
save('finish',y,.65)
# Eight bars, 132 BPM, D minor. Separate bass, percussion, and stereo pluck voices.
bpm=132; beat=60/bpm; length=32*beat
music=np.zeros((round(length*SR),2))
def add(at, a, pan=0):
    start=int(at*SR); end=min(len(music),start+len(a)); a=a[:end-start]
    if end>start:
        music[start:end,0]+=a*np.sqrt((1-pan)/2)
        music[start:end,1]+=a*np.sqrt((1+pan)/2)
for b in range(32):
    t=time(.35)
    kick=np.sin(2*np.pi*(48*t+5.5*(1-np.exp(-t*35))))*np.exp(-t*13)
    add(b*beat,kick*.7)
    if b%4 in (1,3):
        t=time(.22); noise=rng.normal(0,1,len(t)); hp=noise-np.roll(noise,1)
        snare=(hp*.25+np.sin(2*np.pi*175*t)*.2)*np.exp(-t*20)
        add(b*beat,snare*.8,.1)
    for half in range(2):
        t=time(.075 if half==0 else .14); n=rng.normal(0,1,len(t)); n=n-np.roll(n,1)
        add((b+half*.5)*beat,n*np.exp(-t*(70 if half==0 else 27))*.085,(-1)**b*.35)
roots=[38,38,34,34,41,41,36,36]
for step in range(128):
    bar=step//16; local=step%16; root=roots[bar]
    if local in [0,3,6,8,10,14]:
        t=time(beat*.7); f=440*2**((root-69)/12)
        env=np.minimum(t*180,1)*np.exp(-t*13)
        bass=(np.sin(2*np.pi*f*t)+.25*np.sin(2*np.pi*f*2*t)+.12*np.sin(2*np.pi*f*3*t))*env
        add(step*beat/4,bass*.35)
    if step%2==0:
        intervals=[12,19,24,15,19,27,24,19]; note=root+intervals[(step//2)%8]+12
        t=time(.30); f=440*2**((note-69)/12)
        pluck=(np.sin(2*np.pi*f*t)+.2*np.sin(2*np.pi*f*2*t))*np.minimum(t*140,1)*np.exp(-t*15)
        add(step*beat/4,pluck*.11,np.sin(step)*.65)
        add(step*beat/4+beat*.75,pluck*.035,-np.sin(step)*.65)
# Gentle seam envelopes to eliminate loop clicks.
music[:128]*=np.linspace(0,1,128)[:,None]
music[-128:]*=np.linspace(1,0,128)[:,None]
save('music',music,.78)
print(f'Generated {len(list(OUT.glob("*.wav")))} original audio assets in {OUT}')
