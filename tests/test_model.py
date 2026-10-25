import pathlib,random,sys,unittest
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/'sw'))
from triflow_model import Dataflow,TriFlowModel,gemm,wrap
from tiled_gemm import tiled_gemm

class ModelTests(unittest.TestCase):
    def test_register_wavefront_against_independent_gemm(self):
        rng=random.Random(42)
        for n in [1,2,3,4,8]:
            for dw in [4,8]:
                for aw in [2*dw,32]:
                    for trial in range(4):
                        a=[[rng.randrange(-(1<<(dw-1)),1<<(dw-1)) for _ in range(n)] for _ in range(n)]
                        b=[[rng.randrange(-(1<<(dw-1)),1<<(dw-1)) for _ in range(n)] for _ in range(n)]
                        model=TriFlowModel(n,dw,aw); model.load_a(a); model.load_b(b)
                        for mode in Dataflow:
                            with self.subTest(n=n,dw=dw,aw=aw,trial=trial,mode=mode):
                                run=model.run(mode,pause_at=[0,0,3*n-3])
                                self.assertEqual(run.output,gemm(a,b,aw)); self.assertEqual(run.mac_ops,n**3)
                                self.assertEqual(run.stall_cycles,3); self.assertEqual(run.compute_cycles,3*n-2)
                                self.assertEqual(len([x for t in run.trace for x in t['retired']]),n*n)
                                self.assertEqual(run.total_cycles,1+run.preload_cycles+3*n-2+3)
    def test_residency_and_invalidation(self):
        m=TriFlowModel(2); a=[[1,2],[3,4]]; b=[[-1,0],[2,5]]; m.load_a(a); m.load_b(b)
        self.assertFalse(m.run(Dataflow.WS,reuse=True).reuse_used)
        self.assertTrue(m.run(Dataflow.WS,reuse=True).reuse_used)
        m.run(Dataflow.IS); m.run(Dataflow.OS)
        self.assertTrue(m.run(Dataflow.WS,reuse=True).reuse_used)
        m.load_a(a); self.assertTrue(m.run(Dataflow.WS,reuse=True).reuse_used)
        self.assertFalse(m.run(Dataflow.IS,reuse=True).reuse_used)
        m.load_b(b); self.assertFalse(m.run(Dataflow.WS,reuse=True).reuse_used)
    def test_modular_extremes(self):
        for dw in [4,8]:
            a=[[-(1<<(dw-1))]*4 for _ in range(4)]; model=TriFlowModel(4,dw,2*dw)
            model.load_a(a);model.load_b(a)
            for mode in Dataflow: self.assertEqual(model.run(mode).output,[[0]*4 for _ in range(4)])
    def test_rectangular_tiles_and_reuse(self):
        for dims in [(1,1,1),(5,7,3),(9,7,10),(2,9,6)]:
            m,k,p=dims; a=[[(i+j)%9-4 for j in range(k)] for i in range(m)]
            b=[[(i+2*j)%7-3 for j in range(p)] for i in range(k)]
            for mode in Dataflow:
                out,runs=tiled_gemm(a,b,n=4,mode=mode)
                self.assertEqual(out,gemm(a,b,32))
                if mode==Dataflow.WS and m>4: self.assertTrue(any(x.reuse_used for x in runs))
                if mode==Dataflow.IS and p>4: self.assertTrue(any(x.reuse_used for x in runs))
    def test_input_validation_and_copy(self):
        for params in [(0,8,32),(4,1,32),(4,8,8)]:
            with self.assertRaises(ValueError): TriFlowModel(*params)
        m=TriFlowModel(2,4,8)
        with self.assertRaises(ValueError): m.load_a([[8,0],[0,0]])
        with self.assertRaises(ValueError): m.load_b([[0]])
        with self.assertRaises(ValueError): m.run(3)
        with self.assertRaises(ValueError): m.run(0,pause_at=[99])
        with self.assertRaises(ValueError): gemm([[1,2]],[[1]])
        a=[[1,0],[0,1]];m.load_a(a);a[0][0]=7;self.assertEqual(m.a[0][0],1)
    def test_wrap(self):
        self.assertEqual(wrap(128,8),-128);self.assertEqual(wrap(-129,8),127)
        self.assertEqual(wrap(65536,16),0)
if __name__=='__main__': unittest.main()
