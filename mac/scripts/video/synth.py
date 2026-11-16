import numpy as np, wave, os, sys
SR=48000
OUT=os.path.join(os.path.dirname(__file__),'audio')
rng=np.random.default_rng(7)
def save(name,x):
    x=np.asarray(x,dtype=np.float64)
    if x.ndim==1: x=np.stack([x,x],1)
    m=np.max(np.abs(x))+1e-9
    x=x/m*0.89
    d=(x*32767).astype(np.int16)
    with wave.open(os.path.join(OUT,name),'wb') as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(d.tobytes())
def t(n): return np.arange(int(n*SR))/SR
def env(n,a=0.002,d=0.1):
    tt=t(n); e=np.minimum(1,tt/a)*np.exp(-tt/d); return e
def lp(x,a):  # one-pole lowpass
    y=np.zeros_like(x); s=0.0
    for i in range(len(x)): s+=a*(x[i]-s); y[i]=s
    return y
def lp_fast(x,cut):
    # FFT lowpass
    X=np.fft.rfft(x); f=np.fft.rfftfreq(len(x),1/SR); X[f>cut]*=0; return np.fft.irfft(X,len(x))
def bp_fast(x,lo,hi):
    X=np.fft.rfft(x); f=np.fft.rfftfreq(len(x),1/SR); X[(f<lo)|(f>hi)]*=0; return np.fft.irfft(X,len(x))
def reverb(x,dur=2.5,mix=0.3,seed=1):
    r=np.random.default_rng(seed)
    n=int(dur*SR); ir=r.standard_normal(n)*np.exp(-np.arange(n)/SR*3.2/dur*2)
    ir=lp_fast(ir,6000); ir/=np.sqrt(np.sum(ir**2))
    L=len(x)+n; N=1<<int(np.ceil(np.log2(L)))
    y=np.fft.irfft(np.fft.rfft(x,N)*np.fft.rfft(ir,N),N)[:L]
    out=np.zeros(L); out[:len(x)]+=x*(1-mix); out+=y*mix*0.6
    return out

# --- SFX ---
# click: soft UI tick
n=0.06; tt=t(n)
click=(np.sin(2*np.pi*2200*tt)*0.5+np.sin(2*np.pi*3400*tt)*0.3)*env(n,0.0005,0.008)+bp_fast(rng.standard_normal(len(tt)),1500,6000)*env(n,0.0003,0.004)*0.6
save('click.wav',click)
# key: typing tap
n=0.05; tt=t(n)
key=bp_fast(rng.standard_normal(len(tt)),800,5000)*env(n,0.0005,0.006)+np.sin(2*np.pi*900*tt)*env(n,0.0005,0.01)*0.4
save('key.wav',key)
# tick: wheel detent
n=0.03; tt=t(n)
tick=np.sin(2*np.pi*4200*tt)*env(n,0.0002,0.003)+bp_fast(rng.standard_normal(len(tt)),3000,9000)*env(n,0.0002,0.002)*0.5
save('tick.wav',tick)
# whoosh: filtered noise sweep
n=0.55; tt=t(n)
nz=rng.standard_normal(len(tt))
sh=np.sin(np.pi*np.clip(tt/n,0,1))**2
w=np.zeros_like(nz)
for k,(lo,hi) in enumerate([(200,900),(500,1800),(900,3200),(1500,5000)]):
    seg=bp_fast(nz,lo,hi); g=np.exp(-((tt/n-(0.25+k*0.15))/0.18)**2); w+=seg*g
save('whoosh.wav',w*sh)
# swipe: short whoosh
n=0.28; tt=t(n); nz=rng.standard_normal(len(tt))
sw=bp_fast(nz,700,4000)*np.sin(np.pi*tt/n)**3
save('swipe.wav',sw)
# flip: card flip – paper flap + low thump
n=0.35; tt=t(n)
flap=bp_fast(rng.standard_normal(len(tt)),400,3000)*(np.exp(-((tt-0.05)/0.03)**2)+0.7*np.exp(-((tt-0.13)/0.025)**2))
thump=np.sin(2*np.pi*(110-60*tt)*tt)*env(n,0.002,0.08)*0.8
save('flip.wav',flap+thump)
# chime: bell (inharmonic partials)
n=3.0; tt=t(n)
f0=880
parts=[(1,1,1.6),(2.0,0.5,1.0),(2.76,0.35,0.7),(5.4,0.2,0.4),(8.9,0.1,0.25)]
ch=sum(a*np.sin(2*np.pi*f0*r*tt)*np.exp(-tt/d) for r,a,d in parts)*np.minimum(1,tt/0.002)
ch2=sum(a*np.sin(2*np.pi*f0*1.5*r*tt)*np.exp(-tt/d) for r,a,d in parts)*np.minimum(1,np.maximum(0,tt-0.09)/0.002)*0.6
save('chime.wav',reverb(ch+ch2,2.0,0.35))
# reveal: shimmering rising arpeggio (for lot reveal)
n=2.6; tt=t(n); rv=np.zeros_like(tt)
for i,fr in enumerate([523.25,659.25,783.99,1046.5,1318.5]):
    st=i*0.07; m=tt>=st; u=tt[m]-st
    rv[m]+=np.sin(2*np.pi*fr*u)*np.exp(-u/0.9)*np.minimum(1,u/0.004)*(0.9-i*0.1)
save('reveal.wav',reverb(rv,2.4,0.45,3))
# pop: panel open
n=0.18; tt=t(n)
pop=np.sin(2*np.pi*(300+500*np.exp(-tt/0.02))*tt)*env(n,0.001,0.04)
save('pop.wav',pop)
# success: two-note
n=1.2; tt=t(n); su=np.zeros_like(tt)
for st,fr in [(0,659.25),(0.11,987.77)]:
    m=tt>=st; u=tt[m]-st; su[m]+=np.sin(2*np.pi*fr*u)*np.exp(-u/0.35)*np.minimum(1,u/0.003)+0.3*np.sin(2*np.pi*fr*2*u)*np.exp(-u/0.2)
save('success.wav',reverb(su,1.2,0.3,4))
print('sfx done')

# --- MUSIC --- pentatonic ambient, ~72 bpm
dur=float(sys.argv[1]) if len(sys.argv)>1 else 200
N=int(dur*SR); L=np.zeros(N); R=np.zeros(N)
def ks(freq,length=3.0,damp=0.996,bright=0.5,seed=0):
    r=np.random.default_rng(seed)
    n=int(length*SR); p=int(SR/freq)
    buf=r.uniform(-1,1,p)
    buf=lp_fast(np.concatenate([buf]*1),SR*bright/2)[:p] if p>8 else buf
    out=np.zeros(n); idx=0
    b=buf.copy()
    for i in range(n):
        out[i]=b[idx]
        nxt=(idx+1)%p
        b[idx]=damp*0.5*(b[idx]+b[nxt])
        idx=nxt
    return out
# scale: D major pentatonic-ish (D E F# A B) -> calm, bright
base=146.83
scale=[1,9/8,5/4,3/2,5/3]
def note(deg,oct=1):
    o,d=divmod(deg,5); return base*scale[d]*(2**(o+oct))
beat=60/72
# melody pattern (deg, beats)
pattern=[(5,1),(7,0.5),(8,0.5),(9,1),(7,1),(6,1),(5,0.5),(7,0.5),(4,2),
         (5,1),(7,1),(9,0.5),(10,0.5),(9,1),(8,1),(7,2),(5,2)]
cache={}
def pluck(f):
    k=round(f,2)
    if k not in cache: cache[k]=ks(f,2.8,0.9965,0.6,seed=int(f))
    return cache[k]
tpos=beat*8  # melody enters after intro of 2 bars
pi=0
mel=np.zeros(N)
while tpos<dur-6:
    deg,b=pattern[pi%len(pattern)]; pi+=1
    if rng.random()<0.85:
        s=pluck(note(deg,0)); st=int(tpos*SR); e=min(N,st+len(s))
        mel[st:e]+=s[:e-st]*(0.45+0.15*rng.random())
    tpos+=b*beat
# harp-like arpeggio bed (16ths sparse)
arp=np.zeros(N); tpos=0; chords=[[0,2,4,7],[3,5,7,10],[1,3,4,8],[0,2,4,9]]
ci=0
while tpos<dur-4:
    ch=chords[(int(tpos/(beat*4)))%4]
    for k,dg in enumerate(ch):
        tt0=tpos+k*beat*0.5
        s=pluck(note(dg,-1)); st=int(tt0*SR); e=min(N,st+len(s))
        if st<N: arp[st:e]+=s[:e-st]*0.22
    tpos+=beat*2
# pad: detuned sines on chord roots
pad=np.zeros(N); tt=np.arange(N)/SR
roots=[note(0,-1),note(3,-1),note(1,-1),note(0,-1)]
for i in range(int(dur/(beat*4))+1):
    st=i*beat*4; seg=(tt>=st)&(tt<st+beat*4+1.5)
    u=tt[seg]-st
    f=roots[i%4]
    e=np.minimum(1,u/1.2)*np.minimum(1,np.maximum(0,(beat*4+1.5-u))/1.5)
    v=sum(np.sin(2*np.pi*f*m*(1+dt)*u) for m,dt in [(1,0),(1,0.003),(1.5,-0.002),(2,0.001)])
    pad[seg]+=v*e*0.12
drone=np.sin(2*np.pi*base/2*tt)*0.08*(0.7+0.3*np.sin(2*np.pi*0.05*tt))
mix=mel+arp+pad+drone
mix=reverb(mix,3.5,0.4,9)[:N]
# stereo widen
d=int(0.012*SR)
Lc=mix; Rc=np.concatenate([np.zeros(d),mix[:-d]])
fade=np.minimum(1,tt/3)*np.minimum(1,(dur-tt)/4)
st=np.stack([Lc*fade,Rc*fade],1)
save('music.wav',st)
print('music done')
