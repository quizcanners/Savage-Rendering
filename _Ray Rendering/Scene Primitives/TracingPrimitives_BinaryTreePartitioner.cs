using QuizCanners.Inspect;
using UnityEngine;
using QuizCanners.Utils;

namespace QuizCanners.VolumeBakedRendering
{
    public static partial class TracingPrimitives
    {

        public class Leaf 
        {
            public BoundingBoxCalculator Box; 
            public int index;

            public int EffectiveIndex => -index -1;
            
        }

        internal enum SlicePlane { X, Y , Z };

        public class BinaryTreeBranch : IPEGI_Handles
        {
            public readonly BoundingBoxCalculator OptimalBox;
            public readonly BoundingBoxCalculator ActualBox;

            private int _branchIndex = -1;
            private int _totalLeafCount;
            private Leaf _theLeaf;
            private bool _branched;
            private readonly int _depth = 0;

            public bool PredeterminedVolume;

            private BinaryTreeBranch _leftBranch;
            private BinaryTreeBranch _rightBranch;

            internal int GetEffectiveIndex() => _branched ? _branchIndex : _theLeaf.EffectiveIndex;

            public void GenerateTree(Vector4[] binaryTreePositions, Vector4[] binaryTreeSizes) 
            {
                if (!_branched)
                    Debug.LogError("This should be a leaf. Branch index should be -1: "+_branchIndex);

                bool _theLeafProcessed = false;

                ProcessBranch(_leftBranch, out float left);
                ProcessBranch(_rightBranch, out float right);

                if (_theLeaf != null && !_theLeafProcessed)
                    Debug.LogError("The Leaf was never processed");

                binaryTreePositions[_branchIndex] = ActualBox.Center.ToVector4(left);
                binaryTreeSizes[_branchIndex] = ActualBox.Size.ToVector4(right);

                void ProcessBranch(BinaryTreeBranch branch, out float index)
                {
                    if (branch._totalLeafCount > 0)
                    {
                        if (branch._branched)
                            branch.GenerateTree(binaryTreePositions, binaryTreeSizes);

                        index = branch.GetEffectiveIndex();
                    }
                    else
                    {
                        index = _theLeaf.EffectiveIndex;
                        if (_theLeafProcessed)
                            Debug.LogError("Same leaf recordd multiple times");

                        _theLeafProcessed = true;
                    }
                }
            }

            public void IndexNodes(ref int index) 
            {
                if (!_branched)
                    return;

                _branchIndex = index;
                index++;

                _leftBranch.IndexNodes(ref index);
                _rightBranch.IndexNodes(ref index);
            }

            public bool OptimallyContains(Leaf leaf, out float addedVolume) 
                => OptimalBox.Contains(leaf.Box, out addedVolume);

            public bool ActuallyContains(Leaf leaf, out float addedVolume)
          => ActualBox.Contains(leaf.Box, out addedVolume);

            public void Consume(Leaf leaf) 
            {
                ActualBox.Add(leaf.Box);
                _totalLeafCount++;

                if (_totalLeafCount == 1) 
                {
                    _theLeaf = leaf;
                    return;
                }

                if (!_branched)
                {
                    _branched = true;
                    Split();
                }
                
                AddInternal(leaf);

                // When both branches have leafs, there is no more place to record a single leaf
                if (_totalLeafCount>2 && _theLeaf != null && _leftBranch._totalLeafCount>0 && _rightBranch._totalLeafCount > 0) 
                {
                    AddInternal(_theLeaf);
                    _theLeaf = null;
                }

                return;

                void AddInternal(Leaf leafToAdd)
                {
                    if (_leftBranch.OptimallyContains(leafToAdd, out float addedVolumeLeft))
                    {
                        _leftBranch.Consume(leafToAdd);
                        return;
                    }

                    if (_leftBranch.PredeterminedVolume || _rightBranch.OptimallyContains(leafToAdd, out float addedVolumeRight))
                    {
                        _rightBranch.Consume(leafToAdd);
                        return;
                    }

                    _leftBranch.ActuallyContains(leafToAdd, out addedVolumeLeft);
                    _rightBranch.ActuallyContains(leafToAdd, out addedVolumeRight);


                    if (addedVolumeRight < addedVolumeLeft)
                        _rightBranch.Consume(leafToAdd);
                    else
                        _leftBranch.Consume(leafToAdd);
                }

                void Split()
                {
                    var split = GetLongestSide();

                    var center = OptimalBox.Center;
                    var size = OptimalBox.Size;

                    Vector3 splitter = Vector3.Scale(size, split);

                    // Halving size along the longer axis
                    size -= splitter * 0.5f;

                    _leftBranch = new(center - splitter * 0.25f, size, _depth);
                    _rightBranch = new(center + splitter * 0.25f, size, _depth);

                    Vector3 GetLongestSide()
                    {
                        var size = OptimalBox.Size;
                        if (size.x > size.y)
                        {
                            return size.x > size.z ? Vector3.right : Vector3.forward;
                        }
                        else
                        {
                            return size.y > size.z ? Vector3.up : Vector3.forward;
                        }
                    }
                }
            }

            public void RequestABranch(Vector3 center, Vector3 size) 
            {
                if (_branched) 
                {
                    _rightBranch.RequestABranch(center, size);
                    return;
                }

                _branched = true;
                _leftBranch = new(center, size, _depth)
                {
                    PredeterminedVolume = true
                };
                _rightBranch = new(center: ActualBox.Center, size: ActualBox.Size, _depth);
            }

            #region Inspector
            public void OnSceneDraw()
            {
                if (!_branched)
                    return;

                if (PredeterminedVolume)
                    ActualBox.OnSceneDraw(Color.blue);
                else
                    ActualBox.OnSceneDraw(GetColorFromDepth());

                Color GetColorFromDepth() 
                {
                    return Color.Lerp(Color.white, Color.red, _depth/10f);
                }

                _leftBranch?.OnSceneDraw();
                _rightBranch?.OnSceneDraw();
            }

            #endregion

            public BinaryTreeBranch(Vector3 center, Vector3 size, int parentDepth) 
            {
                _depth = parentDepth+1;

                OptimalBox = new()
                {
                    Center = center,
                    Size = size
                };

                ActualBox = new();
            }
        }
    }

     
}
