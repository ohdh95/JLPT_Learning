import sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from translate_examples_service import align

class AlignmentTest(unittest.TestCase):
    def test_multiple_segments_in_one_example_remain_together(self):
        result=align(['Hello. Goodbye.','How are you?'],[
            ['안녕. ','Hello. '],['잘 가.\n','Goodbye.\n'],['어떻게 지내?','How are you?']])
        self.assertEqual(result,['안녕. 잘 가.','어떻게 지내?'])
    def test_changed_truncated_or_crossed_source_is_rejected(self):
        for segments in [
            [['하나','Different.']],
            [['하나','One.']],
            [['하나 둘','One.\nTwo.']],
            [['','One.\n'],['둘','Two.']],
            [['둘','Two.'],['하나','One.\n']],
        ]:
            with self.subTest(segments=segments),self.assertRaises(ValueError):align(['One.','Two.'],segments)

if __name__=='__main__':unittest.main()
